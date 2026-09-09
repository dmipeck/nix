# Skill-commands hard-copy skill content

Slash entry for user-invoked skills used to be a stub
(`Call the Skill tool with "<name>"`), which costs an extra agent cycle
and depends on Skill-tool behavior. We hard-copy each listed skill's
`SKILL.md` description and body into the generated Command, and tool
adapters omit those names from the product skill surface so slash is the
only runtime path. `skillCommands` membership is the sole switch;
`disable-model-invocation` only discovers names for the list. Missing
descriptions fail the build.
