## Run All Task

```bash
just do-lottery
```

## Steps

### Set Lottery Contract

```bash
just set-contracts optimism Lottery false && just set-contracts base ACToken false
```

### Deploy Contracts

```bash
just deploy optimism base
```

### Sanity check to verify that configuration files match with your deployed contracts

```bash
just sanity-check
```

### Create Channel

```bash
just create-channel
```

### Send package

```bash
just send-package
```
