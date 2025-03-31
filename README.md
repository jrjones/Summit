# Summit (Summarize It)

Simple command line tool written in swift that accepts a markdown file or directory of markdown files as input and summarizes them. If they conform to JRJ Obsidian spec, they can be updated to include the summary as obsidian metadata (Summary::)

Works well, designed for DeepSeek-r1 and other reasoning models. Handles the streaming output of chain-of-thought reasoning/thinking to indicate progress, but ends in a nice brief summary.

Uses the summit model, which is based on deepseek-r1. Plan is to fine-tune the model based on traversing all of my meeting notes that have hand-written summaries.

```
Help:  <file>  Path of the Markdown file to summarize.
Usage: summit [--insert] [--model <model>] <file>
  See 'summit --help' for more information.
```

Super simple, really just an adaptation of [my old "summit" shell script](https://github.com/jrjones/jrjscripts/blob/main/summit)