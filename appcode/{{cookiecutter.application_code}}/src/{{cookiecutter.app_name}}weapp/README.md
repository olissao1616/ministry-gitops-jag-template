# JAG-LEA-FRONTEND
## Description
Based on the [LEA mid level design](https://justice.gov.bc.ca/wiki/display/JAM/Mid+Level+Design+Workshops), the frontend will be built using[NEXT.js](https://github.com/vercel/next.js/) which is a React based framework that supports SSR/SSG, Typescript, code splitting and opinionated routing out of the box.

## Project Structure
    .
    ├── src/                                    # Application source files
    │   ├── app/                                # NEXT.js pages
    │   │    ├── _nonRoutingAssets/             # Contains all non routing assets
    │   │    │    ├── assets/                       # Contains css, img, etc
    │   │    │    ├── authProviders/                
    │   │    │    │     └── Providers.tsx            # Used by next-auth to take care of keeping the session updated and synced between browser tabs and windows.
    │   │    │    ├── components/                   # Folder contains non-routable components
    │   │    │    │     ├── AgencyComponent.tsx      # Agency component
    │   │    │    │     ├── AgencyRedirect.tsx       # Page that handles agency redirect when an user has access to only one application
    │   │    │    │     ├── ApplicationComponent.tsx # Application component
    │   │    │    │     ├── BootstrapClient.js       # Component that makes use of "use client" which will load bootstrap javascript only on the client and not the server. 
    │   │    │    │     ├── FooterComponent.tsx      # Footer component
    │   │    │    │     ├── HeaderComponent.tsx      # Header component    
    │   │    │    │     └── UserCard.tsx             # UserCard component, referenced by Header component
    │   │    │    ├── lib/                          # Folder contains non-routable components
    │   │    │    │     └── form.api.ts              # Axios wrapper that dynamically injects cookie and access_token to the header. 
    │   │    │    ├── store/                        # Folder contains state management (jotai state) components
    │   │    │    │     ├── atoms.ts                 # Jotai state(s) definition. 
    │   │    │    │     └── StoreProvide.tsx         # Store provider that makes the store accessible for the application
    │   │    │    ├── types/                        # Folder contains state management (jotai state) components
    │   │    │    │     ├── data-types.ts            # Data type definitions
    |   │    |    │     └── next-auth.d.ts           # Types used by next-auth, which extends the built-in Session and JWT types
    │   │    ├── api/                           
    │   │    │    ├──auth                       # (Don't modify the structure) Next-Auth code to secure the webapp 
    │   │    │    │  └──[...nextauth]
    │   │    │    │        ├── authOptions.ts   # Define/export authOptions to ensure it can be used throughout the application 
    │   │    │    │        └── route.ts         # Define/export NextAuth object
    │   │    │    └──public                     # public API endpoints
    │   │    │       └──health
    │   │    │             └── route.ts         # health check endpoint (noting that it contains the public path, meaning it's not KC protected) 
    │   │    ├── protected/                     # Route segment (it contains page.tsx) that renders agency assignments
    │   │    │    ├── agency/                   # Route segment (it contains page.tsx) that renders agency assignments
    │   │    │    ├── layout.tsx                # Protected layout, all routing elements are protected.
    │   │    │    └── page.tsx                  # Application selection page
    │   │    ├── signin/                        # Route segment that renders custom sign in page
    │   │    ├── error.tsx                      # Route
    │   │    ├── global-error.tsx               # Route
    │   │    ├── layout.tsx                     # Root layout (required), it must define <html> and <body> tags
    │   │    └── page.tsx                       # First page
    │   ├── middleware.ts                       # (Don't relocate the file, Next expects it to be at the src level) Middleware config
    │   └── stories/                            # Storybook
    ├── .env.template                           # Environment setting template
    ├── Dockerfile                              # Dockerfile used by git action to build frontend image
    ├── next.config.js                          # NEXT config file
    ├── nginx.conf                              # Nginx configuration file, used in Dockerfile
    ├── package-lock.json                       # Stores an exact, versioned dependency tree at any given time
    ├── package.json                            # Stores starred version dependency tree
    ├── README.md                               # This file.
    ├── supervisor.conf                         # Supervisor configuration file, used in Dockerfile
    └── tsconfig.json                           # TypeScript project default config file

Note that all none routeable assets or components are placed under folders prefixed with '_', e.g., _components, 

## Installation

```bash
$ npm install
```
## Build the app

```bash
# build
$ npm run build
```

## Running the app

```bash
# development 
# Be sure to create .env.local file based on .env.template, and update the variables' value accordingly.
$ npm run dev

# production mode
$ npm run start:prod
```

## Test

```bash
# unit tests
$ npm run test

# e2e tests
$ npm run test:e2e

# test coverage
$ npm run test:cov
```
