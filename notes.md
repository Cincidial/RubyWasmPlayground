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
