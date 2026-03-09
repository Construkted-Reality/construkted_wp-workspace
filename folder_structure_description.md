Current folder structire

root_folder
   - construkted_api
   - construkted.js
   - construkted_reality_v1.x
   - wordpress

The project is a wordpress SAAS platform. 

The structured has 4 separate sub-parts.
Each part is a separate github project. the wordpress folder has no github repo since there's no code changes there. It's a vanilla install. 

**wordpress** is the main wordpress folder. The development environment is based on DDEV (see context7 for ddev documentation). In the wordpres folder you can run wp-cli commands to evaluate and degub the running wordpress site. you'll need to use prepend ddev to all wp-cli commands. for example "ddev wp db check" or "ddev wp user list"

**construkted_reality_v1.x** contains the theme data. This folder is a separate github project repo. There are two theme folders called gowatch and gowatch-child. The majority of the development is happening inside the child theme. the gowatch theme is there for reference.

**construkted.js** contains the typescript code which runs the CesiumJS 3d viewer and interactions with the 3d environment. This folder is a separate github repo. There is a build process which builds a construkted.js file which then gets copied to "construkted_reality_v1.x/wp-content/themes/gowatch-child/includes/construkted/assets/js" in the gowatch-child theme.

**construkted_api** is server which does processing for converting different types of 3d data into a format that CesiumJs can render. This folder is a separate github repo. this code exposes several api endpoints which are used by the wordpress theme to communicates bi-directionaly with the processing code.

Make sure to note the interconnections between these four folders and if changes are made to one aspect which also affects another project, also implement changes to the affected project.

