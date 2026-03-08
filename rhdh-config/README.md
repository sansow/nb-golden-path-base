# RHDH Configuration

These files are the live configurations extracted from the `tssc-dh` namespace.
Apply with:
```bash
oc create configmap tssc-developer-hub-app-config \
  -n tssc-dh \
  --from-file=app-config.tssc.yaml=rhdh-config/app-config.tssc.yaml \
  --dry-run=client -o yaml | oc apply -f -
```
