# Samples of my work.


It's from app I worked on, some pieces of code has unresolved dependencies and folders structure didn't maintained.
At "screens" folder examples of some pages if it has something to render.
Project is a multi-tenancy PaaS application based on Phoenix LiveView. There are several independent applications: superadmin (for owners),
backoffice (each tenant has it's own management system), client (for end users), one was a core for working with data and
one job server to handle background jobs.
Deployment process works on local docker instances and deploys everything into k8s cluster at DigitalOcean.
Product is an educational platform. It supports:
- webinars/videos (with speakers/participants/chats/calls to actions/real time experience)
- webinar providers: YouTube/zoom/Agora/cloud storage
- courses
- surveys/galleries/polls
- conference module (combining webinars)
- dynamic page builder
- email templates
- multiple independent dealers
- design customisation
- plans & features to manages resources for each clients.
- etc.

###### At this project almost everything was developed by me alone, unfortunately I didn't have enough time to document it well and there was no code reviews to make it better. That's one of the reason I'd like to join to the team to grow and have more feedback on my work

I tried to show code to work with db (Ecto), elixir structures and recursion, couple of LiveView components.

### Emails:
Module for sending emails from application. Works around Bamboo mailer. Added EmailLog to write optionally usage and calculate it per billing periods.
Smtp and SendGridAPI are adapters supported for now.


### Cluster:
Some tasks executed on cluster or communication between apps.

### live_view_components
content_cards to quickly render cards and wrapped into it tabs, it supports mobile devices + left/right/top/bottom positions of tabs (screens are available)
### dynamic_layout
    Most complicated and almost not well documented part. It's a dynamic layout builder in beta and paused for now.
Attempt to bind DOM structure into the elixir/ecto/database structures. 
It supports trees and dynamic editing Dom attributes for each node (partially tailwind module supported).
Custom attributes per node are allowed.
Each node can have data-module (at CMS it's a configurable data: chart, gallery, webinar cart etc.) 
Each node tree could be saved as a block, each block -> used as layout (just a block with selected inner node to put dynamic data).
There is also "Requirements", all requirements are fetched from layout and required to fulfil at page design editor (uploading header image per page etc).

There could be global layouts (available at "public" scheme and shared to tenant's database). 
Tenants can only select them, in this way each customer can use "library" of layouts created by platform's owners. 
Owners can change it at one place to have applied fixes to everybody.
It's on hold because of lack of resources. It requires good frontend work to make it really cool to delivery to end users to create their own layouts.
They use only SuperAdmin layouts and selection at design editor.
