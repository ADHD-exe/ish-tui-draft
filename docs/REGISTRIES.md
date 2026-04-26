# Registries

Default registry root:

```text
/var/lib/iosish/registry
```

Files:

- `aliases.conf`
- `env.conf`
- `helpers.conf`

Modules should write to registries first. Shell config rendering is intentionally deferred.
