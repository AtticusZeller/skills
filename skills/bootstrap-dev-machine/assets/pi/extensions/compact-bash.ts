import { getAgentDir, type ExtensionAPI, type ToolRenderers } from "@earendil-works/pi-coding-agent";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

export default async function (pi: ExtensionAPI) {
  const consumer = join(getAgentDir(), "npm/node_modules/@xzzpig/pi-tool-display/tool-display-api-consumer.js");
  if (!existsSync(consumer)) return;
  const { getToolDisplayApi } = await import(pathToFileURL(consumer).href);

  // Reuse the display plugin's settings without registering a second Bash tool.
  pi.registerToolRenderer((name, next) => {
    const base = next();
    if (name !== "bash") return base;
    const api = getToolDisplayApi();
    if (!api) return base;

    const { renderCall, renderResult }: ToolRenderers = api.decorateTool(
      { name },
      { kind: "bash", overrideExistingRenderers: true },
    );
    return {
      ...base,
      renderCall,
      renderResult(result, options, theme, context) {
        // The plugin previews live output and errors even in summary mode.
        const hideDetails = !options.expanded && (options.isPartial || context.isError);
        return renderResult?.(hideDetails ? { ...result, content: [] } : result, options, theme, context);
      },
    };
  });
}
