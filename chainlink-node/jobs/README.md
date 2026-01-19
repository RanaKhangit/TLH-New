# Chainlink Job Specs

This folder contains example job specifications for our Chainlink node.

## Job Types

| Type | File | Description |
|------|------|-------------|
| Direct Request | `example-direct-request.toml` | Responds to on-chain oracle requests |
| Cron | `example-cron.toml` | Runs on a schedule |
| Webhook | `example-webhook.toml` | Triggered via HTTP endpoint |
| Flux Monitor | `example-flux-monitor.toml` | Price feed with deviation-based updates |

## Adding a Job to the Node

### Via Web UI

1. Go to http://localhost:6688
2. Navigate to **Jobs** > **New Job**
3. Paste the TOML content
4. Click **Create Job**

### Via CLI

```bash
docker compose exec chainlink chainlink jobs create /chainlink/jobs/example-cron.toml
```

## Pipeline Tasks Reference

Common tasks we can use in `observationSource`:

### HTTP Tasks
```toml
fetch [type="http" method=GET url="https://api.example.com/data"]
post [type="http" method=POST url="https://api.example.com" requestData="{\\"key\\": \\"value\\"}"]
```

### JSON Parsing
```toml
parse [type="jsonparse" path="data,price"]           # Nested path: data.price
parseArray [type="jsonparse" path="data,0,value"]    # Array access: data[0].value
```

### Math Operations
```toml
multiply [type="multiply" times="100000000"]         # Multiply by 10^8
divide [type="divide" divisor="1000"]                # Divide by 1000
sum [type="sum"]                                      # Sum multiple inputs
median [type="median"]                                # Get median of inputs
```

### Encoding
```toml
encode [type="ethabiencode" abi="(uint256 value)" data="{\\"value\\": $(input)}"]
```

### Transactions
```toml
submit [type="ethtx" to="0x..." data="$(encoded)"]
```

## Pipeline Flow Syntax

Tasks are connected with `->`:

```toml
observationSource = """
    fetch [type="http" method=GET url="..."]
    parse [type="jsonparse" path="price"]
    multiply [type="multiply" times="100000000"]

    fetch -> parse -> multiply
"""
```

### Multiple Sources (for reliability)

```toml
observationSource = """
    source1 [type="http" url="https://api1.com/price"]
    source2 [type="http" url="https://api2.com/price"]
    source3 [type="http" url="https://api3.com/price"]

    parse1 [type="jsonparse" path="price"]
    parse2 [type="jsonparse" path="data,price"]
    parse3 [type="jsonparse" path="result"]

    median [type="median"]

    source1 -> parse1 -> median
    source2 -> parse2 -> median
    source3 -> parse3 -> median
"""
```

## Resources

- [Chainlink Job Types](https://docs.chain.link/chainlink-nodes/oracle-jobs/job-types)
- [Pipeline Tasks](https://docs.chain.link/chainlink-nodes/oracle-jobs/task-types)
