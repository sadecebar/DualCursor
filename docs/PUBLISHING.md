# Publishing DualCursor

Repository: https://github.com/sadecebar/DualCursor

Keep the complete source in the public repository. Distribute the minimal
Windows ZIP through **GitHub Releases**, not as loose development files.
Users need the Windows ZIP, not GitHub's source-code archive.

## Checklist

1. Build and run the tests in `docs/DEVELOPMENT.md`.
2. Review staged changes. Do not commit settings, logs, device identifiers,
   crash dumps, screenshots of other apps, or test binaries.
3. Preserve `LICENSE` and upstream attribution.
4. Run `powershell -NoProfile -File .\package.ps1 -Version 0.1.0`.
5. Verify the ZIP contains only `DualCursor.exe`, `README.md`, and `LICENSE`
   inside its `DualCursor` folder. Test the extracted executable.
6. Commit the source and create the matching tag, for example `v0.1.0`.
7. Draft a release for that tag on the repository's **Releases** page.
8. Attach `dist/DualCursor-v0.1.0-windows-x64.zip` and its `.sha256` file.
9. Review the release notes, then publish.

Suggested notes:

> Two physical mice with separate colored pointers on one Windows computer,
> per-mouse monitor locks, and mouse automation routing for tools such as
> TinyTask. Download the Windows x64 ZIP, extract it, and run DualCursor.exe.
> Windows 10/11 x64 required. The executable is unsigned. Foreground focus
> remains shared, and conflicting clicks are skipped while a mouse button is
> held. Read the included README before using automation. Free and open source
> under the MIT License.

Git ignores `build`, `dist`, executables, IDE state, and local settings/logs.
Never release a build compiled with `DUALCURSOR_TESTING`. The packaging script
always makes a fresh normal build.

Use a new version/tag for future releases rather than replacing published
downloads. A checksum detects changed bytes; it is not a signing certificate.

Official references:
- [Creating a repository](https://docs.github.com/en/get-started/start-your-journey/creating-a-repository-for-your-project-on-github)
- [Managing releases](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)
