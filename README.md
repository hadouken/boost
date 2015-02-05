# Overview

This repository contains the build script to download, build and publish
Boost for Hadouken on Windows.

Boost is built with MSVC-12 (Visual Studio 2013).

## Building

```
CMD> powershell -ExecutionPolicy RemoteSigned -File build.ps1
```

This will download and compile Boost in both debug and release versions for
Win32.

The output (including a NuGet package) is put in the `bin` folder.