# Jenkins Test Example
Learning Jenkins. Simple example with docker deployment from Git repo using a pipeline.

## Run Jenkins
```sh
docker compose up -d
```

## Deploy example
This example will use [`dummy-website`](https://github.com/kirillsaidov/dummy-website) for deployment. 

### Create a Pipeline Job in Jenkins
1. Open Jenkins (http://localhost:8080)
2. Click "New Item"
3. Enter a name (e.g., "dummy-website-deployment")
4. Select "Pipeline"

### Configure the Pipeline
1. Scroll down to the "Pipeline" section
2. In "Definition" dropdown, select "Pipeline script from SCM"
3. In "SCM" dropdown, select "Git"
4. In "Repository URL", enter: https://github.com/kirillsaidov/dummy-website.git
5. In "Branch Specifier", enter: */main
6. In "Script Path", enter: Jenkinsfile (this is the default)

### Remote deployment
Configure SSH Server in Jenkins:
1. Go to **Manage Jenkins** → **Plugins** → Install **"Publish Over SSH"**
2. Go to **Manage Jenkins** → **System**
3. Scroll to **"Publish over SSH"** section
4. Click **"Add"** under SSH Servers:
   - **Name:** `server-name`
   - **Hostname:** `hostname-or-url`
   - **Username:** Your SSH username (e.g., `ubuntu` or `root`)
   - Click **"Advanced"** button
   - Select **"Use password authentication, or use a different key"**
   - **Password:** Your SSH password
   - **Port:** `22` (default)
5. Click **"Test Configuration"** to verify connection
6. Click **"Save"**

Now use the `Jenkins.remote` file for deployment pipeline.

### Run the Pipeline

Click **"Build Now"**. Watch the build progress in the left sidebar and click on the build number to see details.

## LICENSE
Unlicense.


