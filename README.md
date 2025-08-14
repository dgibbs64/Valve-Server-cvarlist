# Valve Server CVar Lists

Curated collection of server console variable (cvar) dumps for a wide range of Valve (GoldSrc / Source / Source 2) and community game servers. Each `*-cvarlist.txt` file contains the raw output of the `cvarlist` command captured shortly after a clean install and first launch of the dedicated server using [LinuxGSM](https://linuxgsm.com/).

The goal is to provide a reproducible, version‑agnostic reference for:

- Auditing available server configuration options
- Change tracking between engine / game updates
- Tooling (parsing / docs generation / diffing)
- Quick lookups without spinning up a server

---

## Repository Contents

File naming pattern: `<shortname>-cvarlist.txt` where `shortname` matches the LinuxGSM server script prefix (e.g. `tf2server`).

Current lists:

| Shortname | Game / Mod                                 | File                    |
| --------- | ------------------------------------------ | ----------------------- |
| ahl       | Action Half-Life                           | `ahl-cvarlist.txt`      |
| ahl2      | Action Half-Life 2                         | `ahl2-cvarlist.txt`     |
| bb        | BrainBread                                 | `bb-cvarlist.txt`       |
| bb2       | BrainBread 2                               | `bb2-cvarlist.txt`      |
| bd        | Base Defense                               | `bd-cvarlist.txt`       |
| bs        | Blade Symphony                             | `bs-cvarlist.txt`       |
| bmdm      | Black Mesa: Deathmatch                     | `bmdm-server.txt`       |
| cc        | Codename CURE                              | `cc-cvarlist.txt`       |
| cs        | Counter-Strike 1.6                         | `cs-cvarlist.txt`       |
| cs2       | Counter-Strike 2                           | `cs2-cvarlist.txt`      |
| cscz      | Counter-Strike: Condition Zero             | `cscz-cvarlist.txt`     |
| css       | Counter-Strike: Source                     | `css-cvarlist.txt`      |
| dab       | Double Action: Boogaloo                    | `dab-cvarlist.txt`      |
| dmc       | Deathmatch Classic                         | `dmc-cvarlist.txt`      |
| dods      | Day of Defeat: Source                      | `dods-cvarlist.txt`     |
| doi       | Day of Infamy                              | `doi-cvarlist.txt`      |
| dys       | Dystopia                                   | `dys-cvarlist.txt`      |
| em        | Empires Mod                                | `em-cvarlist.txt`       |
| fof       | Fistful of Frags                           | `fof-cvarlist.txt`      |
| gmod      | Garry's Mod                                | `gmod-cvarlist.txt`     |
| hl2dm     | Half-Life 2: Deathmatch                    | `hl2dm-cvarlist.txt`    |
| hldm      | Half-Life Deathmatch                       | `hldm-cvarlist.txt`     |
| hldms     | Half-Life Deathmatch: Source               | `hldms-cvarlist.txt`    |
| ins       | Insurgency                                 | `ins-cvarlist.txt`      |
| ios       | IOSoccer                                   | `ios-cvarlist.txt`      |
| l4d       | Left 4 Dead                                | `l4d-cvarlist.txt`      |
| l4d2      | Left 4 Dead 2                              | `l4d2-cvarlist.txt`     |
| nd        | Nuclear Dawn                               | `nd-cvarlist.txt`       |
| nmrih     | No More Room in Hell                       | `nmrih-cvarlist.txt`    |
| ns        | Natural Selection                          | `ns-cvarlist.txt`       |
| opfor     | Opposing Force                             | `opfor-cvarlist.txt`    |
| pvkii     | Pirates, Vikings, & Knights II             | `pvkii-cvarlist.txt`    |
| ricochet  | Ricochet (Placeholder)                     | `ricochet-cvarlist.txt` |
| sfc       | SourceForts Classic                        | `sfc-cvarlist.txt`      |
| sven      | Sven Co-op                                 | `sven-cvarlist.txt`     |
| tf2       | Team Fortress 2                            | `tf2-cvarlist.txt`      |
| tfc       | Team Fortress Classic                      | `tfc-cvarlist.txt`      |
| ts        | The Specialists                            | `ts-cvarlist.txt`       |
| vs        | Vampire Slayer                             | `vs-cvarlist.txt`       |
| zmr       | Zombie Master Reborn                       | `zmr-cvarlist.txt`      |
| zps       | Zombie Panic! Source                       | `zps-cvarlist.txt`      |

`serverlist.csv` can be used as a manifest (future tooling potential).

> Note: Some descriptions above marked "example" or "placeholder" should be validated; feel free to submit corrections.

---

### Usage

Run from the repository root:

```bash
./get_cvars.sh <shortname>
```

Example (Team Fortress 2):

```bash
./get_cvars.sh tf2
```
