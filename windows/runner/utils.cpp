#include "utils.h"

#include <flutter_windows.h>
#include <io.h>
#include <stdio.h>
#include <windows.h>

#include <iostream>

void CreateAndAttachConsole() {
  if (AllocConsole()) {
    FILE* unused;
    freopen_s(&unused, "CONOUT$", "w", stdout);
    freopen_s(&unused, "CONOUT$", "w", stderr);
    freopen_s(&unused, "CONIN$", "r", stdin);
    std::ios::sync_with_stdio();
  }
}

std::vector<std::string> GetCommandLineArguments() {
  int argc;
  wchar_t** argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return std::vector<std::string>();
  }

  std::vector<std::string> command_line_arguments;
  command_line_arguments.reserve(argc - 1);

  for (int i = 1; i < argc; ++i) {
    std::wstring arg = argv[i];
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, &arg[0], (int)arg.size(),
                                          NULL, 0, NULL, NULL);
    std::string arg_utf8(size_needed, 0);
    WideCharToMultiByte(CP_UTF8, 0, &arg[0], (int)arg.size(), &arg_utf8[0],
                        size_needed, NULL, NULL);
    command_line_arguments.push_back(arg_utf8);
  }

  LocalFree(argv);

  return command_line_arguments;
}
