# Mod IO Functions

All these functions are available on your mod object.

## fileExists

Checks if a file exists in the mod directory.

`boolean myMod:fileExists(filePath)`

## directoryExists

Checks if a directory exists in the mod directory.

`boolean myMod:directoryExists(directoryPath)`

## readFileAsString

Reads a whole file as a single string.

`boolean, string myMod:readFileAsString(filePath)`

## writeFileAsString

Writes a string in a file.

`boolean myMod:writeFileAsString(filePath, fileContent)`

## createDirectory

Creates a directory in the mod directory.

`boolean myMod:createDirectory(directoryPath)`

## moveFile

Moves/renames a file or directory within the mod directory.

`boolean myMod:moveFile(sourcePath, destinationPath)`

## deleteFile

Deletes a file within the mod directory.

`boolean myMod:deleteFile(filePath)`

## deleteDirectory

Deletes a directory and all its content within the mod directory.

`boolean myMod:deleteDirectory(directoryPath)`

mod-io-functions.txt · Last modified: 2026/02/23 16:54 by polymorphgames
