# Tilt local development for the generated GitOps repo.
# This Tiltfile is intentionally thin: configuration lives in tilt/tiltconfig.json.

# Usage:
#   tilt up
#   tilt up -- --env=dev
#   tilt up -- --env=test
#
# Optional (recommended): create tilt/tilt.local.json from the example and set allowContexts.

config.define_string('env')
parsed = config.parse()

def deep_merge(dst, src):
    for k in src.keys():
        if k in dst and type(dst[k]) == 'dict' and type(src[k]) == 'dict':
            deep_merge(dst[k], src[k])
        else:
            dst[k] = src[k]

# Read and merge config
cfg_path = 'tilt/tiltconfig.json'
local_cfg_path = 'tilt/tilt.local.json'

cfg = decode_json(read_file(cfg_path))

# Merge local overrides if present
if os.path.exists(local_cfg_path):
    local_cfg = decode_json(read_file(local_cfg_path))
    deep_merge(cfg, local_cfg)

# Pick env from Tilt args
selected_env = parsed.get('env')
if selected_env == None or selected_env == '':
    selected_env = cfg.get('defaultEnv', 'dev')

envs = cfg.get('envs', {})
if selected_env not in envs:
    fail('Unknown env: %s. Expected one of: %s' % (selected_env, sorted(envs.keys())))

env = envs[selected_env]
namespace = env.get('namespace')
values_file = env.get('valuesFile')
local_values_file = env.get('localValuesFile')
release_name = env.get('releaseName', cfg.get('releaseName', 'gitops'))
openshift_enabled = env.get('openshift', False)

if namespace == None or values_file == None:
    fail('tiltconfig is missing env namespace/valuesFile for env=%s' % selected_env)

# Safety: limit allowed contexts
allow_contexts = cfg.get('allowContexts', [])
if allow_contexts and len(allow_contexts) > 0:
    allow_k8s_contexts(allow_contexts)

k8s_namespace(namespace)

# OpenShift: ensure Tilt recognizes Routes as Kubernetes resources
if openshift_enabled:
    k8s_kind('Route')

# Render manifests via Helm
if cfg.get('helmDependencyUpdate', True):
    local('helm dependency update ./charts/gitops')

rendered = helm(
    './charts/gitops',
    name=release_name,
    namespace=namespace,
    values=([values_file] + ([local_values_file] if local_values_file and os.path.exists(local_values_file) else [])),
)

# Local (non-OpenShift) clusters won't have the Route API; drop Routes when openshift is disabled.
if not openshift_enabled:
    rendered = filter_yaml(rendered, kind='Route')
k8s_yaml(rendered)

# Configure resource labels (from groups) and port-forwards
resources = cfg.get('resources', {})

# Tilt doesn't have a first-class "group" UI, but it does support labels.
# We map `groups` from config into resource labels so you can filter in the UI.
groups = cfg.get('groups', {})
resource_labels = {}
for gname in groups.keys():
    for r in groups[gname]:
        if r not in resource_labels:
            resource_labels[r] = []
        if gname not in resource_labels[r]:
            resource_labels[r].append(gname)

for rname in resources.keys():
    r = resources[rname]

    objects = r.get('objects', [])
    openshift_objects = r.get('openshiftObjects', [])
    port_forwards = r.get('portForwards', [])

    # Tilt accepts port forwards like "8080:8080"
    pf = []
    for p in port_forwards:
        pf.append(str(p))

    resource_kwargs = {}
    labels = resource_labels.get(rname, [])
    if labels and len(labels) > 0:
        resource_kwargs['labels'] = labels

    # NOTE: We intentionally do NOT pass `objects=` into k8s_resource here.
    # Tilt auto-creates resources from workload objects (Deployment/StatefulSet/etc).
    # If we try to re-assign those workload objects via `objects=`, Tilt will error
    # because those objects are no longer "remaining".
    obj = []
    if objects != None and len(objects) > 0:
        obj = obj + objects
    if openshift_enabled and openshift_objects != None and len(openshift_objects) > 0:
        obj = obj + openshift_objects
    if len(pf) > 0:
        resource_kwargs['port_forwards'] = pf

    # k8s_resource configures an existing (auto-created) resource.
    # We derive the auto resource name from the workload object(s), then rename it
    # to the friendly key (backend/frontend/postgresql).
    deploy_name = None
    statefulset_name = None
    has_route_for_deploy = False

    for o in obj:
        if type(o) != 'string':
            continue

        # Object fragments are formatted like "name:Kind" (e.g. "myapp:Deployment")
        if o.endswith(':Deployment'):
            deploy_name = o.rsplit(':', 1)[0]
        elif o.endswith(':StatefulSet'):
            statefulset_name = o.rsplit(':', 1)[0]
        elif deploy_name != None and o == (deploy_name + ':Route'):
            has_route_for_deploy = True

    auto_name = None
    if deploy_name != None and deploy_name != '':
        # When a Route shares the same name as a Deployment, Tilt disambiguates
        # the Deployment resource as "name:deployment".
        if openshift_enabled and has_route_for_deploy:
            auto_name = deploy_name + ':deployment'
        else:
            auto_name = deploy_name
    elif statefulset_name != None and statefulset_name != '':
        auto_name = statefulset_name

    if auto_name != None:
        k8s_resource(auto_name, new_name=rname, **resource_kwargs)
    else:
        # Fallback: configure by friendly name (only works if auto resource name already matches)
        k8s_resource(rname, **resource_kwargs)
