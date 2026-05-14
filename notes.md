# Project Goals
1. Fetch many files from github
    1. Able to fetch based on branch / commit 
2. Parse serialized ruby data from rxdata files. Use this data to 
    1. Build an interactive map
    2. Build a wiki of non PBS data
3. Parse PBS files. Use this data to
    1. Perform the pokedex functions (team builder, dex, etc.)
        1. Teambuilder use URLs instead of codes (bigger, but easier for users to use, which is the point)
    2. Allow edits to this data and save the files (if local PBS changes apply in game without a build then this makes sense, otherwise no point)
4. Use image files
    1. For large display
    2. For icon display (may need parsing of the image)
5. Perform parsing locally without the need for a server host to run jobs to update the data (time of fetch automatically gets up-to-date data)
6. Ability to call ruby functions from JS. For damage calc for example
7. Cheap or free hosting (would be amazing if this could be on github pages)

# Problems to Solve
- Github doesn't want to be treated like a CDN, but hosting the files ourselves means keeping up to date somehow. Possible solutions
    - Somehow fetch by folder from github, store locally with commit hash 
        - I don't think we'll be able to do this. Github is actively dissallowing this behavior
    - Have a server that clones the repo, when it gets a file request serve it by first checking out the commit hash (alphanumeric, which is important for sanitization vs branch name) 
        - Going this route means we could do more work on the server (ie. parsing the PBS). But that also adds the complication of logic in 2 places (server and client) when we could just leave it to the client
        - Some stuff might be required here, like pre-processing of pokemon icon images to strip it down to just one image
            - Doing this here is nice vs tectonic method of having to update the repo
    - Github actions could be used to pre-build big batch files of the data, which can then be used by github pages. The problems here though are
        - Images don't play well with this
        - Using dev commits will require deployments
        - Updating the website will require a deployment
- Calling Ruby from JS
    - Looks like there's a ruby-wasm runtime. Using this we can import ruby scripts and call them from JS

# Direction 1
- Github pages hosting (note - this does mean pure JS is easiest?)
- Config file with list of commit hashes from the game repos to support
- Use a script on build to do the following, for each game repo hash
    - Clone the repo
    - Generate a sprite atlas of all the images required
        - Imagemagick with --apend
    - Build a JSON file with the following
        - Parsed PBS data
        - Parsed Ruby data (from seralized ruby files)
        - Sprite-atlas slicing info
            - Need to self-generate this while doing Imagemagick
                - Will need move all images to one folder, then processes in same glob order
                - May need to set image size limits? 
                    - https://imagemagick.org/command-line-options/#append&gsc.tab=0
    - Conact all ruby scripts into 1 ruby script file (new-line seperating should be enough?) that can be used by ruby-wasm (via `requireRemote`)
- Upload files to `./dist/<hash>/` on publish
- Provide a settings option on the website to set the hash to use (no drop-down, manually enter only)
    - On change re-fetch all data and re-process it all

# Direction 2
- Hosted backing server
    - Rational: 
        - Rate limits and need for image pre-processing (pokemon icons) and desire for first-class-dev support (using files from a commit) throw a wrench in the plan to use github pages
    - Operations:
        - Handles only 1 GET request route `GetFile(string commitHash = "")`
            - When the hash is empty use the current release
            - Either manually update, or use the latest tagged release from the game repo
        - When fetching a file
            - Check the cache for "file_path+hash"
                - If found serve it
            - Clone the repo, if not done already
            - Checkout the hash
            - Perform file specific stuff (image processing, pbs processing, etc)
            - Add the file+hash to cache
            - Serve the file

# RPG Events
Determining what to show on a tile given keywords the event on it contains

Other:
    - vendingMachine

Map changing:
    - avatarChamberDoor
    ^ mapTransitionTransfer

Trainers:
    ^ pbTrainerBattle (somehwere in the event list)
        - Also see setBattleRule
    - NON-BATTLE-NPC:
        - This is indicated by an event having a graphic that uses a 'character_name' value of a sprite 
        and it is not a map change, item or trainer battle
    - IGNORE: 
        ^ Events with resetfollower in their name

Avatars: (this is tectonic specific, but still fun to have in to show what's possible)
    - introduceAvatar

Items: 
    - defeatBoss // Seems to be avatars only
    ^ pbItemBall
    ^ pbReceiveItem
    ^ pbPickBerry

 ^ Encounter tiles:
    - Use terrarin tags along side the mappings in this file (will need manual updates for Eon Park) to map from terrain tag to encounter type 
        - https://github.com/Pokemon-Tectonic-Team/Pokemon-Tectonic-Content/blob/17ab40cb718188ec6d10b34a1b07c929ec7dd1a0/Plugins/Chasm%20Game%20Data/Static%20Data/TerrainTag.rb#L354
        - Then use this one to map to the PBS data https://github.com/Pokemon-Tectonic-Team/Pokemon-Tectonic-Content/blob/17ab40cb718188ec6d10b34a1b07c929ec7dd1a0/Plugins/Chasm%20Other/WildPokemon/EncounterChecks.rb#L200

Gift pokemon tiles:
    - pbAddPokemon
        - Sometimes the pokemon is an object created before hand for setup, in which case param passed in here won't match an actual ID of a mon
          So you'll need to read for other EventCommand entries in that same list and find 'Pokemon.new'

Trade pokemon
    - pbStartBoxTrade & helpers to determine the conditions needed

# Up Next
- Parse PBS data into a JSON object
- Use a font from the game data
- Make a guide on how to set this up via forking, then each dev can have their own dev branch with hash to checkout. Save on build time
