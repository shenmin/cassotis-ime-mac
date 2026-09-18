-- Only customize the supplied, temporary disk image; leave other Finder windows alone.
on run arguments
    set mountPath to item 1 of arguments
    set imageAlias to (POSIX file mountPath) as alias
    with timeout of 60 seconds
        tell application "Finder"
            set imageFolder to folder imageAlias
            open imageFolder
            set imageWindow to container window of imageFolder
            set current view of imageWindow to icon view
            set toolbar visible of imageWindow to false
            set statusbar visible of imageWindow to false
            set bounds of imageWindow to {180, 140, 940, 652}
            set viewOptions to icon view options of imageWindow
            set arrangement of viewOptions to not arranged
            set icon size of viewOptions to 80
            set text size of viewOptions to 13
            set label position of viewOptions to bottom
            set shows item info of viewOptions to false
            set shows icon preview of viewOptions to false
            set background picture of viewOptions to file ".background:background.tiff" of imageFolder
            set position of item "言泉输入法安装器.app" of imageFolder to {274, 326}
            set position of item "安装说明.txt" of imageFolder to {494, 326}
            close imageWindow
            open imageFolder
            update imageFolder without registering applications
            delay 2
            close container window of imageFolder
        end tell
    end timeout
end run
