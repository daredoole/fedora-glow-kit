# Revert and Recovery

Use the guided revert:

```bash
bash manage.sh --revert core
bash manage.sh --revert kde
bash manage.sh --revert ai
bash manage.sh --revert extras
bash manage.sh --revert security
bash manage.sh --revert all
```

Backups are written beside changed files with `.bak.TIMESTAMP`.

The kit records installed package state under:

```text
~/.local/state/fedora-plasma-glow-kit/install.state
```

For compatibility, older installs may still have:

```text
~/.local/state/fedora-starter-kit/install.state
```
