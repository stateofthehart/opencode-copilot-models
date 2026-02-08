import type { Plugin } from "@opencode-ai/plugin"
import { readFile } from "fs/promises"
import { join } from "path"
import { homedir } from "os"

interface CopilotModel {
  id: string
  model_picker_enabled?: boolean
  capabilities?: { type?: string }
}

interface ModelsResponse {
  data: CopilotModel[]
}

async function discoverEnabledModels(config: any): Promise<void> {
  // Read OAuth token from OpenCode's auth storage
  const dataDir = process.env.XDG_DATA_HOME || join(homedir(), ".local", "share")
  const authPath = join(dataDir, "opencode", "auth.json")

  let authData: any
  try {
    authData = JSON.parse(await readFile(authPath, "utf-8"))
  } catch {
    return // No auth file
  }

  const copilotAuth = authData["github-copilot"]
  if (!copilotAuth?.access && !copilotAuth?.refresh) return

  const token = copilotAuth.access || copilotAuth.refresh
  if (typeof token !== "string" || token.length === 0) return

  // Query models endpoint directly with the OAuth token
  // (OpenCode sends gho_ tokens directly to api.githubcopilot.com)
  const res = await fetch("https://api.githubcopilot.com/models", {
    headers: {
      Authorization: `Bearer ${token}`,
      "Copilot-Integration-Id": "vscode-chat",
      "Content-Type": "application/json",
    },
    signal: AbortSignal.timeout(4000),
  })

  if (!res.ok) return

  let models: ModelsResponse
  try {
    models = (await res.json()) as ModelsResponse
  } catch {
    return // Malformed response
  }
  if (!models.data?.length) return

  // Filter to picker-enabled chat models only
  const enabledIds = models.data
    .filter((m) => m.model_picker_enabled && m.capabilities?.type === "chat")
    .map((m) => m.id)

  if (enabledIds.length === 0) return

  // Set whitelist on the github-copilot provider
  if (!config.provider) config.provider = {}
  if (!config.provider["github-copilot"]) config.provider["github-copilot"] = {}
  config.provider["github-copilot"].whitelist = enabledIds
}

const CopilotModelsPlugin: Plugin = async () => {
  return {
    config: async (config: any) => {
      try {
        await Promise.race([
          discoverEnabledModels(config),
          new Promise<void>((resolve) => setTimeout(resolve, 5000)),
        ])
      } catch {
        // Silent fail — don't block startup
      }
    },
  }
}

export { CopilotModelsPlugin }
export default CopilotModelsPlugin
