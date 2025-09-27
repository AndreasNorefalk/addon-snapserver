# Home Assistant Community Add-on: Snapcast

<p align="center">
  <a href=""><img src="https://img.shields.io/badge/version-2024.12-blue" /></a>
  <a href=""><img src="https://img.shields.io/badge/project-experimental-yellow" /></a>
  <a href="https://github.com/Art-Ev/addon-snapserver/blob/main/LICENSE.md"> <img src="https://img.shields.io/badge/licence-mit-green" /></a>
</p>

## About this add-on

This Home Assistant add-on bundles a [Snapserver](https://github.com/badaix/snapcast) instance
that can be managed directly from your Home Assistant installation. Snapserver is the
central component of the Snapcast ecosystem and is responsible for receiving audio from
one or more sources and distributing perfectly synchronized streams to Snapclient
players around your home. The add-on configures PulseAudio, Bluetooth, Librespot, and
Snapweb automatically so you can focus on selecting the audio sources you want to share.
With this add-on you can:

* Provide a multi-room audio backbone that keeps every speaker in sync.
* Combine multiple audio inputs, such as Spotify via Librespot or a Bluetooth source,
  and make them available to any Snapclient. The add-on automatically exposes a
  Bluetooth sink that forwards audio into Snapserver via a FIFO pipe.
* Configure buffering, codecs, and transport protocols (TCP/HTTP) through the add-on
  options panel without leaving the Home Assistant UI.
* Take advantage of the included Snapweb interface that lets you manage streams and
  client volumes from any browser.

## Configuration

The `streams` option accepts one URI per line. The add-on automatically prefixes each
line with `source =` when rendering `snapserver.conf`, so both of the examples below are
valid:

```
streams: |
  spotify:///librespot?name=Spotify&bitrate=320
  pipe:///tmp/snapfifo?name=Bluetooth&sampleformat=44100:16:2&type=pipe&mode=read
```

You can still provide fully formed `source = ...` statements if you prefer. Additional
sources can be supplied via `stream_bis` and `stream_ter`.

Running Snapserver as an add-on means it benefits from Home Assistant's lifecycle
management: it starts automatically with your system, integrates into Supervisor
backups, and exposes the necessary ports and devices so you can attach USB audio
interfaces or Bluetooth adapters when needed.

## Contributing

This is an active open-source project. Totally to people who want to
use the code or contribute to it.

Thank you for being involved! :heart_eyes:

## Contributors
<a href="https://github.com/Art-Ev/addon-snapserver/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=Art-Ev/addon-snapserver" />
</a>

## Want more Home assistant add-ons ?
Check HA community addons [here](https://github.com/hassio-addons) !

## License

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[armhf-shield]: https://img.shields.io/badge/armhf-no-red.svg
[armv7-shield]: https://img.shields.io/badge/armv7-yes-green.svg
[commits-shield]: https://img.shields.io/github/commit-activity/y/hassio-addons/addon-spotify-connect.svg
[commits]: https://github.com/hassio-addons/addon-spotify-connect/commits/main
[contributors]: https://github.com/hassio-addons/addon-spotify-connect/graphs/contributors
[discord-ha]: https://discord.gg/c5DvZ4e
[discord-shield]: https://img.shields.io/discord/478094546522079232.svg
[discord]: https://discord.me/hassioaddons
[docs]: https://github.com/hassio-addons/addon-spotify-connect/blob/main/spotify/DOCS.md
[forum-shield]: https://img.shields.io/badge/community-forum-brightgreen.svg
[forum]: https://community.home-assistant.io/t/home-assistant-community-add-on-spotify-connect/61210?u=frenck
[frenck]: https://github.com/frenck
[github-actions-shield]: https://github.com/hassio-addons/addon-spotify-connect/workflows/CI/badge.svg
[github-actions]: https://github.com/hassio-addons/addon-spotify-connect/actions
[github-sponsors-shield]: https://frenck.dev/wp-content/uploads/2019/12/github_sponsor.png
[github-sponsors]: https://github.com/sponsors/frenck
[i386-shield]: https://img.shields.io/badge/i386-yes-green.svg
[issue]: https://github.com/hassio-addons/addon-spotify-connect/issues
[license-shield]: https://img.shields.io/github/license/hassio-addons/addon-spotify-connect.svg
[maintenance-shield]: https://img.shields.io/maintenance/yes/2022.svg
[patreon-shield]: https://frenck.dev/wp-content/uploads/2019/12/patreon.png
[patreon]: https://www.patreon.com/frenck
[project-stage-shield]: https://img.shields.io/badge/project%20stage-experimental-yellow.svg
[reddit]: https://reddit.com/r/homeassistant
[releases-shield]: https://img.shields.io/github/release/hassio-addons/addon-spotify-connect.svg
[releases]: https://github.com/hassio-addons/addon-spotify-connect/releases
[repository]: https://github.com/hassio-addons/repository
