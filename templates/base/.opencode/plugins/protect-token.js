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
const SECRET_ON_ARGV = new RegExp(`(dart-define|--verbose)\\s[^|;&]*\\$\\{?(${SECRETS})`, 'i')

// Reading a real .env through cat, head, or a pager. Global so matchAll finds
// every reader command on the line; matchAll clones the regex, so lastIndex
// never leaks between calls.
const ENV_READER = /(?:^|[|;&]\s*)(?:cat|head|tail|less|more|bat)\s+/gi

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

export const ProtectToken = async () => ({
  'tool.execute.before': async (input, output) => {
    if (input.tool === 'bash') {
      if (typeof output.args.command !== 'string') deny(REASONS.missingBashArg)
      const command = output.args.command
      if (PRINTS_SECRET.test(command)) deny(REASONS.printsSecret)
      if (DUMPS_ENV.test(command)) deny(REASONS.dumpsEnv)
      if (CURL_VERBOSE.test(command)) deny(REASONS.curlVerbose)
      if (SECRET_ON_ARGV.test(command)) deny(REASONS.secretOnArgv)
      for (const reader of command.matchAll(ENV_READER)) {
        const segment = command
          .slice(reader.index + reader[0].length)
          .split(/[|;&]/)[0]
        for (const token of segment.split(/\s+/)) {
          // A flag such as --file=.env carries the path after the equals sign.
          const eq = token.indexOf('=')
          const candidates =
            eq === -1 ? [token] : [token, token.slice(eq + 1)]
          for (const candidate of candidates) {
            if (isRealEnv(basename(stripQuotes(candidate)))) {
              deny(REASONS.envRead)
            }
          }
        }
      }
      return
    }
    if (input.tool === 'read') {
      if (typeof output.args.filePath !== 'string') deny(REASONS.missingReadArg)
      if (isRealEnv(basename(output.args.filePath))) deny(REASONS.envRead)
    }
  },
})
