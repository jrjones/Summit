# Summit

**Summit** is a simple command-line tool written in Swift that summarizes Markdown files using a local language model (via [Ollama](https://github.com/jmorganca/ollama)). When inserted into your workflow, Summit can help you quickly generate or update concise summaries in your Markdown notes, particularly if they follow JRJ's Obsidian note structure (Summary:: metadata).

## Features
1. **Summarize Markdown Files**
	- Provide a short, concise summary of a single Markdown file or an entire directory of Markdown files.
	- The summary avoids extraneous details like dates/times and focuses on brief clarity.

2. **Optional Summary Insertion**
	- If your Markdown file contains a line like Summary:: or Summary:: Needs Review, Summit can insert or replace that line with the generated summary.
	- The resulting line will appear in your file as, for example: `Summary:: ✨This is the short summary that Summit generated`

3. **Streaming Chain-of-Thought**
	- Summit uses Ollama's streaming API, allowing you to see its "thinking" process if the model returns chain-of-thought data (wrapped in <think>...</think>).
	- The chain-of-thought is displayed live in the console but not included in the final written summary.

4. **Directory Support**
	- Provide a directory, and Summit will automatically summarize each .md file within that directory, optionally inserting the summaries as it goes.

5. **Pluggable Model**
	- By default, Summit calls the "summit:latest" model, but you can override this with the --model argument to use any model hosted by your local Ollama instance.

## Requirements
• **Swift 5.5+ -** Required to compile and run Summit.
• **Ollama - ** Must be installed and running locally on the default port (localhost:11434) so Summit can communicate with it. See the [Ollama GitHub project](https://github.com/jmorganca/ollama) for details on installation and model management.

## Installation
1. **Clone this repository** or copy the Summit.swift file into a working directory.
2. **Build with Swift Package Manager** (SPM) or Xcode: `swift build -c release` This should produce a binary (e.g., in .build/release/Summit).
3. **Install** (optional) by moving the generated binary to your system's PATH: `cp .build/release/Summit /usr/local/bin/summit`
4. Ensure **Ollama** is running: `ollama run`

By default, it listens on port 11434.

## Usage
```    
USAGE: summit [--insert] [--model <model>] <file>
ARGUMENTS:
      <file>  Path of the Markdown file (or directory of Markdown files) to summarize.
    
OPTIONS:
      -i, --insert       Insert the summary into the file (replacing "Summary::" line).
      -m, --model        Ollama model name (default: "summit:latest").
      -h, --help         Show help information.
```

## Configuration
The tool will look for the existence of a file in the user's home directory called `org.jrj.summit.config.plist` - if it is present, it will use those values. Otherwise, it will use defaults.
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>promptTemplate</key>
    <string>Please create a short summary of this markdown note. Don't include dates or times. Be as concise as possible, include acronyms, abbreviations, etc. for brevity.</string>
    <key>model</key>
    <string>summit:latest</string>
    <key>endpointURL</key>
    <string>http://localhost:11434/api/generate</string>
</dict>
</plist>
```

## Examples
1. **Generate a summary without inserting it**:
    `summit MeetingNotes.md` will read MeetingNotes.md, show a streaming generation in the console, and then print the final short summary.
2. **Insert the summary into the file**:
    `summit --insert MeetingNotes.md` If the file contains Summary:: or Summary:: Needs Review, Summit will replace that line with the new summary. Otherwise, it will only show the summary but not modify the file.
3. **Summarize a directory**: 
    `summit Documents/Notes` Summit processes every .md file inside Documents/Notes, displaying summaries for each file.
4. **Use a custom model**:
    `summit --model myCustomModel:latest MeetingNotes.md` Summit will call Ollama with the specified model instead of the default "summit:latest".

## How It Works
1. **Prompt Construction**
Summit prepares a short system prompt instructing the model to generate a concise, date-less summary. It then appends the file's contents to the prompt.
2. **Ollama Streaming**
  - Summit sends the prompt to Ollama's /api/generate endpoint (listening at localhost:11434).
  - As Ollama streams back tokens, Summit prints chain-of-thought (marked with <think>...</think>) to the console, while accumulating the final answer into finalSummary.
3. **Cleaning & Insertion**
  - Extra newlines and carriage returns are removed from the final summary.
  - If --insert is provided, Summit scans the original Markdown content for lines matching Summary:: or Summary:: Needs Review. The first matching line is replaced with: `Summary:: ✨<your final summary here>`

The updated file is then written back to disk.

## History/Context
This tool is an adaptation of [my old "summit" shell script](https://github.com/jrjones/jrjscripts/blob/main/summit). Contributions are welcome--feel free to open issues or submit pull requests for improvements, bug fixes, or new features.

# License
Licensed under MIT License [[LICENSE]]

