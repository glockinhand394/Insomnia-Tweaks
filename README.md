# 🌙 Insomnia Tweaks

An Insomnia-branded Windows setup, maintenance and optimisation toolbox based on the open-source Chris Titus Tech Windows Utility.

The original WinUtil workflows are retained and customised with Insomnia branding, a purple theme (`#A75ED6`), an **Insomnia Twerks** tab label, and support for the repository's `insomnia.png` logo.

## Features

- **Install** — browse, search, select, install, uninstall and upgrade applications.
- **Insomnia Twerks** — use the built-in Windows tweak catalogue and presets.
- **Config** — access Windows configuration and troubleshooting tools.
- **Updates** — configure Windows Update behaviour.
- **Win11 Creator** — use the included Windows installation media creation workflow.
- **Appx** — manage supported built-in Windows apps.
- Original application catalogue, tweak definitions, configuration data and supporting functions.

## Repository layout

Keep the logo file in the repository root:

```text
Insomnia-Tweaks/
├── insomnia.png
├── InsomniaTweaks.ps1
├── Compile.ps1
├── scripts/
├── functions/
├── config/
└── xaml/
```

`insomnia.png` is loaded for the navigation logo and application window icon. If it is missing, the original vector logo is used as a fallback.

## Run

Open PowerShell as Administrator in this repository folder, then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\InsomniaTweaks.ps1
```

The launcher runs `Compile.ps1` to build the customised single-file `winutil.ps1`, then starts it. You can also build manually with:

```powershell
powershell -ExecutionPolicy Bypass -File .\Compile.ps1
```

## Important

This utility makes system-level Windows changes. Review selected tweaks before applying them, create a restore point, and make sure you understand the effect of each operation. Some features require Administrator permissions and an internet connection.

## Credits and licence

This project is based on [Chris Titus Tech's WinUtil](https://github.com/ChrisTitusTech/winutil).

The upstream project is distributed under the MIT License. Its original `LICENSE` file and copyright notice are retained in this repository. The upstream code and its contributors remain credited to their original authors. Insomnia-specific modifications are separate customisations.

See [LICENSE](LICENSE) for the full licence text.
