# ForwardTrail Default Addon

To use: 

* [Download Addon](https://github.com/forwardtrail/addon/archive/master.zip) and unzip it 

* from the addon folder in Terminal, run `rake setup`

* Edit `addon.yml` configure addon (please follow instructions in this file)

* Run `rake install` to upload your addon to ForwardTrail (staging account)

* Run `ADDON_ENV=production rake install` to upload your addon to ForwardTrail (production account)

... more docs coming soon ...

TODO: documentation for

- add CSS overrides (`addon.css`)
- add JS widgets (`client/*.js`)
- server component (event types)
- configure options