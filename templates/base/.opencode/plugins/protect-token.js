// Denies a tool call that would print a secret or read a real .env file.
//
// Why a plugin and not a rule: docs/rules/SECURITY.md can tell an agent never to
// log a token, but only the harness can stop it. This hooks tool.execute.before
// and throws on a matching call. Every other call returns normally and falls
// through to the normal permission flow.
//
// Allowed: existence and length checks such as ${#GITHUB_TOKEN}, passing a token
//          to a tool as an auth header, and reading a committed .env template.
// Blocked:  echo/printf/cat/tee of a token value, environment dumps, curl
//           verbose modes, secrets on the command line, and reads of a real .env.
//
// Reference: https://opencode.ai/docs/plugins

const SECRETS =
  'GITHUB_TOKEN|GH_TOKEN|GITLAB_TOKEN|FIREBASE_TOKEN|FIREBASE_API_KEY|FLUTTERFIRE_TOKEN|GCLOUD_SERVICE_KEY|SUPABASE_SERVICE_ROLE|OPENAI_API_KEY|ANTHROPIC_API_KEY|GEMINI_API_KEY|NPM_TOKEN|PUB_HOSTED_URL|DART_AUTH_TOKEN'

// A Firebase web API key travels in URLs by design, so it is the one secret
// the URL rule still allows.
const URL_SECRETS = SECRETS.replace('FIREBASE_API_KEY|', '')

const deny = (reason) => {
  throw new Error(reason)
}

// Printing a value: an expansion inside a printer.
const PRINTS_SECRET = new RegExp(
  `(echo|printf|cat|tee|printenv|env|export|set)\\s[^|;&]*\\$\\{?(${SECRETS})([A-Za-z0-9_]*)?\\}?`,
  'i',
)

// A whole-environment dump, only where a command can start. A bare `env` in
// argument position (cd env, ls env, npm run env) is a folder or task name, not
// a dump, so other positions stay allowed.
const DUMPS_ENV = /(^|[|;&]\s*)(env|printenv|export -p|set)\s*($|[|;&])/i

// curl verbose modes print the Authorization header to stderr.
const CURL_VERBOSE = /curl[^|;&]*(-v|--verbose|--trace(-ascii|-ascii)?|--trace-config)/i

// Debug/network tooling that echoes a full request, headers included.
const SECRET_ON_ARGV = new RegExp(`(dart-define|--verbose|-d|--data(?:-raw|-binary)?|--form|-F)(?:\\s|=)[^|;&]*\\$\\{?(${SECRETS})`, 'i')

// A secret interpolated into a URL travels to the URL host.
const SECRET_IN_URL = new RegExp(
  `(?:https?|wss?)://[^\s|;&]*\\$\{?(${URL_SECRETS})`,
  'i',
)

// Reading a real .env through cat, head, or a pager. Global so matchAll finds
// every reader command on the line; matchAll clones the regex, so lastIndex
// never leaks between calls.
const ENV_READER =
  /(?:^|[|;&]\s*)(?:cat|head|tail|less|more|bat|grep|rg|ag|ack)\s+/gi

// Copying a secrets file off the machine. Local staging (cp, mv, tar, zip)
// stays allowed; the network boundary is what this rule guards.
const NETWORK_EXIT =
  /(?:^|[|;&]\s*)(?:scp|sftp|rsync|rcp|nc|netcat|aws|gcloud|gsutil|az|docker|kubectl)\s+/gi
const REASONS = {
  printsSecret:
    'Blocked: this command prints a secret value. Report the presence and length instead, and pass the token to a tool as an auth header.',
  dumpsEnv:
    'Blocked: this command dumps the environment, which includes secrets. Print only the specific non-sensitive value you need.',
  curlVerbose:
    'Blocked: curl verbose output prints request headers including Authorization. Remove the verbose flag.',
  secretOnArgv:
    'Blocked: this command passes a secret on the command line, where it lands in the process list and shell history.',
  envRead:
    'Blocked: this reads a .env file. Report the presence and length of a variable instead, or read a committed .env.example.',
  missingBashArg:
    'Blocked: the Bash command argument is missing, so the tool contract may have changed. Re-send the command through the Bash tool or report the mismatch.',
  missingReadArg:
    'Blocked: the read file path is missing, so the tool contract may have changed. Report the mismatch instead of retrying the read.',
  secretInUrl:
    'Blocked: this command interpolates a secret into a URL, which sends it to the URL host. Pass it as an auth header instead.',
  secretWrite:
    'Blocked: this writes to a credentials or key file. Ask the user before touching secrets storage.',
}

// Committed templates: how an agent learns the variable names.
const ENV_TEMPLATES = new Set([
  '.env.example',
  '.env.sample',
  '.env.template',
  '.env.defaults',
])

const basename = (filePath) => filePath.split(/[\\/]/).pop() ?? ''

// One layer of shell quoting is not part of the file name. Strip any run of
// quotes at the ends; a token the shell actually produced never has them.
const stripQuotes = (token) => token.replace(/^["']+|["']+$/g, '')

const isRealEnv = (name) =>
  name === '.env' ||
  name.endsWith('.env') ||
  (name.startsWith('.env.') && !ENV_TEMPLATES.has(name))
// Credential and key files by basename. Not exhaustive; .env names are
// handled by isRealEnv above.
const SECRET_FILES = new Set([
  'key.properties',
  '.netrc',
  'secrets.yaml',
  'secrets.json',
  'credentials',
  'id_rsa',
  'id_dsa',
  'id_ecdsa',
  'id_ed25519',
])

const SECRET_SUFFIXES = ['.jks', '.keystore', '.p12', '.pfx', '.pem', '.key']

const isSecretPath = (name) =>
  isRealEnv(name) ||
  SECRET_FILES.has(name) ||
  SECRET_SUFFIXES.some((suffix) => name.endsWith(suffix)) ||
  /^service-account.*\.json$/.test(name)

const segmentAfter = (command, match) =>
  command.slice(match.index + match[0].length).split(/[|;&]/)[0]

// True when one of the path arguments after a reader or copy command names
// a secrets file.
const touchesSecretPath = (command, match) => {
  for (const token of segmentAfter(command, match).split(/\s+/)) {
    const eq = token.indexOf('=')
    for (const candidate of eq === -1 ? [token] : [token, token.slice(eq + 1)]) {
      if (isSecretPath(basename(stripQuotes(candidate)))) return true
    }
  }
  return false
}

export const ProtectToken = async () => ({
  'tool.execute.before': async (input, output) => {
    if (input.tool === 'bash') {
      if (typeof output.args.command !== 'string') deny(REASONS.missingBashArg)
      const command = output.args.command
      if (PRINTS_SECRET.test(command)) deny(REASONS.printsSecret)
      if (DUMPS_ENV.test(command)) deny(REASONS.dumpsEnv)
      if (CURL_VERBOSE.test(command)) deny(REASONS.curlVerbose)
      if (SECRET_ON_ARGV.test(command)) deny(REASONS.secretOnArgv)
      if (SECRET_IN_URL.test(command)) deny(REASONS.secretInUrl)
      for (const reader of command.matchAll(ENV_READER)) {
        if (touchesSecretPath(command, reader)) deny(REASONS.envRead)
      }
      for (const exit of command.matchAll(NETWORK_EXIT)) {
        if (touchesSecretPath(command, exit)) deny(REASONS.envRead)
      }
      return
    }
    if (input.tool === 'read') {
      if (typeof output.args.filePath !== 'string') deny(REASONS.missingReadArg)
      if (isSecretPath(basename(output.args.filePath))) {
        deny(REASONS.envRead)
      }
    }
    if (input.tool === 'write' || input.tool === 'edit') {
      if (typeof output.args.filePath !== 'string') deny(REASONS.missingReadArg)
      if (isSecretPath(basename(output.args.filePath))) {
        deny(REASONS.secretWrite)
      }
    }
  },
})
