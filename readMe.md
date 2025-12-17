# StrataFi Protocol - Smart Contracts

Decentralized structured finance platform built on Aptos blockchain.

## Overview

StrataFi transforms illiquid real-world credit assets into liquid, tradable digital instruments.

### Key Features
-  **Risk Tranching**: Senior, Mezzanine, and Junior tranches
-  **Fungible Asset Tokens**: Each tranche as tradable FA
-  **Bonding Curve Pricing**: Optional AMM-style pricing
-  **Atomic Settlement**: Powered by Aptos Block-STM

## Tech Stack

- **Blockchain**: Aptos
- **Language**: Move
- **Token Standard**: Fungible Assets (FA) + Coin

## Module Structure
```
sources/
├── core/
│   ├── tokens/
│   │   ├── stratifi.move       # STFI protocol token (Coin)
│   │   └── pools_token.move    # Pool token factory (FA)
│   ├── pools.move              # Pool management (WIP)
│   ├── tranche.move            # Tranche logic (WIP)
│   ├── waterfall.move          # Payment distribution (WIP)
│   └── oracle.move             # Risk oracle (WIP)
└── utils/
    ├── math.move               # Bonding curve calculations
    └── errors.move             # Error codes
```

## Development Status

 **Under Active Development**

- [x] STFI protocol token
- [x] Pool token factory
- [x] Math utilities for bonding curves
- [ ] Pool creation & securitization
- [ ] vault modules
- [ ] Investment & deposit logic
- [ ] Waterfall distribution engine
- [ ] Oracle integration
- [ ] Compliance layer (KYC/AML)

## Building
```bash
aptos move compile
```

## Testing
```bash
aptos move test
```

## License

MIT

---

**Built with Move on Aptos**