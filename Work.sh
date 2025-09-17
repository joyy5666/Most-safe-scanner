# initialize git
git init
git add .
git commit -m "Initial commit — script safety tool"

# add remote — replace <USERNAME> and <REPO> with your GitHub username and repo name
git remote add origin https://github.com/<USERNAME>/<REPO>.git

# push the first time to set upstream (you'll be prompted for GitHub username/password or PAT)
git branch -M main
git push -u origin main
