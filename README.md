# MacroLabor
A repo of code and literature from the Macro Field course, taught by Carter Braxton.

# Getting Up and Running
0. All code in this repo assumes that the working directory is set to `code`.
1. [Globals.do](code/Globals.do) contains relative file paths used by the `.do` files. You should notice that one of the file paths points to a folder titled `data`. You will have to set this
folder up before executing any of the scripts here. <mark>Raw data files that populate the `data` folder are available upon request.</mark>
2. Set your fredkey in Stata. This project uses the `import fred` command in Stata. That means you will need an API key for fred. You can request one [here](https://fred.stlouisfed.org/docs/api/api_key.html). See the [import fred](https://www.stata.com/manuals/dimportfred.pdf) documentation to see how to set it
