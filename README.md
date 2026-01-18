# Lab Assistant
This was a passion project after developing my own B&W film at home. It personally felt intimidating jugling so many things at once, and felt it could easily be modernized.

This app allows you to create personalized step by step workflows for film development. It is also synced on iCloud to enable multi-device work.

[Get it on the App Store!](https://apps.apple.com/us/app/lab-assistant-darkroom-timer/id6754861810)

## Technical Details + Learnings
Though meant to be a simple passion project, there was absolutely learnings as I experimented with new technologies!

A large goal of this was the inclusion of iCloud support, as I wanted to be able to work quickly on my phone to create these and have them sync to my iPad to display them on a large screen while developing.

[Guides](https://www.hackingwithswift.com/books/ios-swiftui/syncing-swiftdata-with-cloudkit) by Paul Hudson were fairly sufficient for this task. However I had a huge issue with getting the schema to properly sync. I realized eventually that a schema needs to be set for anything to sync, however to actually tell iCloud this it needs to know these schemas, which need to be done on a test device which when an object is added it will tell iCloud the schema. Then you can finally publish the schema and everything will sync properly. A bit of a nightmare but also iCloud support was added part way through. 

Overall, I am quite happy with this project and using it to develop C41 for the first time took a huge mental load off which was super helpful. 
