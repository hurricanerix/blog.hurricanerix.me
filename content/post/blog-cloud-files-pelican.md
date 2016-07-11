+++
date = "2015-07-18T22:09:00-05:00"
draft = false
title = "Setting up a blog with Pelican & Rackspace Cloud Files"
tags = [ "Blog", "Cloud Files", "Hugo" ]
+++

From time to time I have the desire to share my thoughts on a topic.  Having resisted Twitter for many years, in 2013, I finally caved in.  As much as I like Twitter, I find the 140 character limit very restrictive when attempting to write anything of significance.  Most times, I just get frustrated trying to re-phrase things to fit.  This leads to most tweets that actually make it being the result of my scorn.  Had I had more than 140 characters, I would have at least explained my issue rather than "@CompanyX Wha wha wha[^fn-wha_footnote]".  Having intended to create a blog for a while now, and after looking over Pelican, I decided that this was the direction to go.

Part I: Setup
-------------

The first thing to do is create a directory[^fn-apology_footnote] for the blog.  Since I intend for my blog to live at http://blog.hurricanerix.me, I decided to use that as my directory name[^fn-src-control_footnote].

```
$ mkdir blog.hurricanerix.me
$ cd blog.hurricanerix.me
```

Managing the requirements is much easier if you create a file to contain them.  As you can see here, I have created a requirements.txt file and placed everything that is needed into it.

```
$ cat requirements.txt
pelican
Markdown
jinja2
python-swiftclient
```

Installing them with pip is also quite easy[^fn-virtualenv_footnote].

```
$ pip install -r requirements.txt
Downloading/unpacking pelican (from -r requirements.txt (line 1))
...
Successfully installed pelican Markdown jinja2 python-swiftclient six python-dateutil docutils pygments blinker unidecode pytz feedgenerator markupsafe futures requests
Cleaning up...
```

Part II: Rackspace Cloud Files
------------------------------

Assuming you already have a Rackspace account[^fn-rackspace-account_footnote], use curl, along with your username and api-key to retrieve your service catalog.  You will receive a lot more data back than what I have shown below, I have modified the output some so the things we care about stand out more clearly.

```
$ curl -XPOST https://identity.api.rackspacecloud.com/v2.0/tokens  \
 -d '{"auth":{"RAX-KSKEY:apiKeyCredentials":{"username":"<username>","apiKey":"<api-key>"}}}' \
 -H "Content-type: application/json" | python -m json.tool
{
    "access": {
        "serviceCatalog": [
            {
                "endpoints": [
                    {
                        "publicURL": "{cdn-management-url}",
                        "region": "DFW",
                    },
                ],
                "name": "cloudFilesCDN",
            },
            {
                "endpoints": [
                    {
                        "publicURL": "{storage-url}",
                        "region": "DFW",
                    },
                ],
                "name": "cloudFiles",
            },
        ],
        "token": {
            "id": "{auth-token}",
        },
    }
}
```

* `{storage-url}` - Used to create the container, looks something like the following: "https://storage101.dfw1.clouddrive.com/v1/MossoCloudFS_######".
* `{cdn-management-url}` - Used to CDN enable the container, looks something like the following: "https://cdn1.clouddrive.com/v1/MossoCloudFS_######".
* `{auth-token}` - Used to make authenticated requests, looks like a lot of random numbers and letters.

Use the `{auth-token}` and `{storage-url}` to create a container.  Be sure to add the header "X-Container-Meta-Web-Index: index.html", which will enable the static website feature on the container.

```
$ curl -i -XPUT -H'x-auth-token: <auth-token>' {storage-url}/blog_container \
-H "X-Container-Meta-Web-Index: index.html"
HTTP/1.1 201 Created
Content-Length: 0
Content-Type: text/html; charset=UTF-8
X-Trans-Id: txa9f1c685b6874297bf442-0055ab2ed8dfw1
Date: Sun, 19 Jul 2015 05:00:08 GMT
```

Now that we have a container, use the `{auth-token}` and `{cdn-management-url}` to CDN enable the container.

```
$ curl -i -XPUT -H'x-auth-token: <auth-token>' https://cdn1.clouddrive.com/v1/MossoCloudFS_***/blog_container \
-H'X-Cdn-Enabled: True'
HTTP/1.1 201 Created
X-Cdn-Uri: http://ac21aa663c28be3f02f3-c1c0bd7ff67c987fa086e7438ac1472a.r46.cf1.rackcdn.com
```

DNS is outside the scope of this article, but provided you have a domain, you can now create a CNAME record pointing it to the value returned in the `X-Cdn-Url` header.

Part III: Setup Pelican
-----------------------

Since I will be committing my changes to github, I don't want to have my `{username}`, `{api-key}` in the make file that Pelican will generate[^fn-github-key_footnote].  Instead I will put these more sensitive things into a ENV variable which the makefile can access.  Here I am exporting them from the shell, but you may wish to add them to your .bashrc file so you don't have to export them every time.

```
$ export PELICAN_CLOUDFILES_USERNAME="<your-username>"
$ export PELICAN_CLOUDFILES_API_KEY="<your-api-key>"
```

Pelican comes with a great quickstart script, which we will take advantage of.

```
$ pelican-quickstart
Welcome to pelican-quickstart v3.6.0.

This script will help you create a new Pelican-based website.

Please answer the following questions so this script can generate the files
needed by Pelican.


> Where do you want to create your new web site? [.]
> What will be the title of this web site? blog.hurricanerix.me
> Who will be the author of this web site? Richard Hawkins
> What will be the default language of this web site? [en]
> Do you want to specify a URL prefix? e.g., http://example.com   (Y/n) n
> Do you want to enable article pagination? (Y/n) y
> How many articles per page do you want? [10]
> What is your time zone? [Europe/Paris] America/Chicago
> Do you want to generate a Fabfile/Makefile to automate generation and publishing? (Y/n) y
> Do you want an auto-reload & simpleHTTP script to assist with theme and site development? (Y/n) y
> Do you want to upload your website using FTP? (y/N) n
> Do you want to upload your website using SSH? (y/N) n
> Do you want to upload your website using Dropbox? (y/N) n
> Do you want to upload your website using S3? (y/N) n
> Do you want to upload your website using Rackspace Cloud Files? (y/N) y
> What is your Rackspace Cloud username? [my_rackspace_username] $(PELICAN_CLOUDFILES_USERNAME)
> What is your Rackspace Cloud API key? [my_rackspace_api_key] $(PELICAN_CLOUDFILES_API_KEY)
> What is the name of your Cloud Files container? [my_cloudfiles_container] blog_container
> Do you want to upload your website using GitHub Pages? (y/N) n
Done. Your new project is available at blog.hurricanerix.me
```

Now all that is left is to place a markdown file in the content directory and run `make cf_upload` to push your new blog to Cloud Files.

```
$ make cf_upload
pelican blog.hurricanerix.me/content -o blog.hurricanerix.me/output -s blog.hurricanerix.me/publishconf.py
WARNING: Feeds generated without SITEURL set properly may not be valid
Done: Processed 1 article, 0 drafts, 0 pages and 0 hidden pages in 0.15 seconds.
cd blog.hurricanerix.me/output && swift -v -A https://auth.api.rackspacecloud.com/v1.0 -U **** -K **** upload -c blog_container .
archives.html
tags.html
tag/cloud-files.html
tag/pelican.html
index.html
tag/blog.html
theme/images/icons/youtube.png
feeds/all.atom.xml
setting-up-a-blog-with-pelican-rackspace-cloud-files.html
theme/images/icons/google-plus.png
theme/images/icons/linkedin.png
theme/images/icons/google-groups.png
theme/images/icons/speakerdeck.png
theme/images/icons/lastfm.png
categories.html
theme/images/icons/rss.png
theme/images/icons/delicious.png
theme/images/icons/reddit.png
theme/images/icons/bitbucket.png
authors.html
theme/images/icons/aboutme.png
feeds/tutorial.atom.xml
theme/images/icons/vimeo.png
theme/images/icons/slideshare.png
theme/images/icons/gittip.png
theme/images/icons/gitorious.png
theme/images/icons/hackernews.png
theme/images/icons/github.png
theme/css/wide.css
theme/css/pygment.css
theme/css/reset.css
theme/images/icons/stackoverflow.png
theme/css/main.css
theme/css/typogrify.css
category/tutorial.html
author/richard-hawkins.html
theme/images/icons/facebook.png
theme/images/icons/twitter.png
```

![Browser with the new blog loaded](/images/setting-up-a-blog-with-pelican-rackspace-cloud-files_finished.png)

[^fn-wha_footnote]: An attempt at a crying baby sound.

[^fn-apology_footnote]: Sorry Microsoft Windows users, I use Linux Mint for my development needs.  You might still be able to follow along, but it won't be as easy as it will be for the OS-X crowd.

[^fn-src-control_footnote]: This would also be a good time to setup version control on your directory.  I will be using a private Github repo so that I can push draft posts if needed.

[^fn-virtualenv_footnote]: I created a virtual environment to do my dev work in, if you are not using one, you may have to run pip with the `sudo` command.

[^fn-rackspace-account_footnote]: If you do not already have a Racksapce Cloud account, head on over and sign up for one. http://www.rackspace.com

[^fn-github-key_footnote]: Even though I am using a private Github repo, it is still bad practice to commit things like passwords or API keys.
