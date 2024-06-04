# Spark PSM

![Foundry CI](https://github.com/mars-foundation/spark-psm/actions/workflows/ci.yml/badge.svg)
[![Foundry][foundry-badge]][foundry]
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://github.com/mars-foundation/spark-psm/blob/master/LICENSE)

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

PSM contracts to either:
- Convert between a tokenization of an asset (ex. USDC) and a yield-bearing version of the asset (ex. sDAI).
- Convert one to one between directly correlated assets (ex. USDC-DAI).

## [CRITICAL]: First Depositor Attack Prevention on Deployment

On the deployment of the PSM, the deployer **MUST make an initial deposit to get AT LEAST 1e18 shares in order to protect the first depositor from getting attacked with a share inflation attack**. This is outlined further [here](https://github.com/marsfoundation/spark-automations/assets/44272939/9472a6d2-0361-48b0-b534-96a0614330d3). Technical details related to this can be found in `test/InflationAttack.t.sol`. The deployment script [TODO] in this repo contains logic for the deployer to perform this initial deposit, so it is **HIGHLY RECOMMENDED** to use this deployment script when deploying the PSM. Reasoning for the technical implementation approach taken is outlined in more detail [here](https://github.com/marsfoundation/spark-psm/pull/2).

## Usage

```bash
forge build
```

## Test

```bash
forge test
```

***
*The IP in this repository was assigned to Mars SPC Limited in respect of the MarsOne SP*
