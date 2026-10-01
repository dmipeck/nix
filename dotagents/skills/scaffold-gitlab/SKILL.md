---
name: scaffold-gitlab
description: >-
  Configure a new GitLab project with a minimal feature set and
  fast-forward merge defaults. Use when creating a GitLab repo/project,
  `glab repo create`, scaffolding a GitLab remote, or setting up GitLab
  project features / merge request settings for a fresh project.
---

Configure a **new** GitLab project after creation (or while creating it). Prefer
`glab` + the Projects REST API. Ask for project path/visibility only when not
already decided; otherwise proceed with the defaults below.

## Target shape

**Features on** (everything else off):

| UI | API field | Value |
|---|---|---|
| Work items | `issues_access_level` | `enabled` |
| Repository | `repository_access_level` | `enabled` |
| Repository → Merge requests | `merge_requests_access_level` | `enabled` |
| Repository → CI/CD | `builds_access_level` | `enabled` |

**Features off** (set each to `disabled`; also `packages_enabled=false`,
`lfs_enabled=false`, `service_desk_enabled=false`):

`wiki_access_level`, `snippets_access_level`, `pages_access_level`,
`analytics_access_level`, `container_registry_access_level`,
`security_and_compliance_access_level`, `releases_access_level`,
`environments_access_level`, `feature_flags_access_level`,
`infrastructure_access_level`, `monitor_access_level`,
`model_experiments_access_level`, `model_registry_access_level`,
`package_registry_access_level`, `requirements_access_level`,
`forking_access_level`.

**Merge requests:**

| Setting | API | Value |
|---|---|---|
| Fast-forward merge | `merge_method` | `ff` |
| Encourage squash commits | `squash_option` | `default_on` |
| Automatic rebase prior to merge | `automatic_rebase_enabled` | `true` |

`only_allow_merge_if_pipeline_succeeds` (`Pipelines must succeed`): set `true`
only when CI is configured. CI means the project has (or is about to gain) a
root `.gitlab-ci.yml` / `.gitlab-ci.yaml`, or another committed pipeline config
the agent is adding. No CI file and none planned → leave unset/`false`.

## Steps

1. **Create the project** if it does not exist:

```bash
glab repo create [<group>/]<name> --private   # or --public / --internal
```

Capture the project path or numeric id from the response.

2. **Apply features + merge defaults** with `PUT /projects/:id`.
   `automatic_rebase_enabled` is **write-only** and ignored on create — always
   set it on this update. URL-encode `/` in path ids as `%2F`.

```bash
PROJECT='<group>%2F<name>'   # or numeric id

glab api --method PUT "projects/${PROJECT}" \
  -f issues_access_level=enabled \
  -f repository_access_level=enabled \
  -f merge_requests_access_level=enabled \
  -f builds_access_level=enabled \
  -f wiki_access_level=disabled \
  -f snippets_access_level=disabled \
  -f pages_access_level=disabled \
  -f analytics_access_level=disabled \
  -f container_registry_access_level=disabled \
  -f security_and_compliance_access_level=disabled \
  -f releases_access_level=disabled \
  -f environments_access_level=disabled \
  -f feature_flags_access_level=disabled \
  -f infrastructure_access_level=disabled \
  -f monitor_access_level=disabled \
  -f model_experiments_access_level=disabled \
  -f model_registry_access_level=disabled \
  -f package_registry_access_level=disabled \
  -f packages_enabled=false \
  -f requirements_access_level=disabled \
  -f forking_access_level=disabled \
  -f lfs_enabled=false \
  -f service_desk_enabled=false \
  -f merge_method=ff \
  -f squash_option=default_on \
  -f automatic_rebase_enabled=true
```

3. **Pipelines must succeed** — only if CI is configured (see above):

```bash
glab api --method PUT "projects/${PROJECT}" \
  -f only_allow_merge_if_pipeline_succeeds=true
```

If CI lands later in the same session, run this update then.

4. **Verify** with a GET and confirm the readable fields match the target
   shape (`merge_method`, `squash_option`, access levels,
   `only_allow_merge_if_pipeline_succeeds` when set).
   `automatic_rebase_enabled` is not returned by the API — treat a successful
   PUT as done; if the instance rejects the field (older than ~19.4), report
   that the UI checkbox under **Settings → Merge requests** still needs
   enabling.

```bash
glab api "projects/${PROJECT}" | jq '{
  issues_access_level, repository_access_level,
  merge_requests_access_level, builds_access_level,
  wiki_access_level, snippets_access_level, pages_access_level,
  merge_method, squash_option,
  only_allow_merge_if_pipeline_succeeds
}'
```

Report the project URL and the settings applied (including whether pipelines
must succeed was enabled).
