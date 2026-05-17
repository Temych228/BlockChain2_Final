# InsureDAO — Инструкция по запуску

## Важно

Все контракты **уже задеплоены** на Arbitrum Sepolia. Фронтенд настроен на эти адреса.  
**Повторный деплой не требуется** — проект полностью работает «из коробки».

---

## 1. Требования

| Компонент | Минимальная версия | Установка |
|-----------|-------------------|-----------|
| Node.js | >= 18 | https://nodejs.org/ |
| Foundry (forge, cast) | latest | `curl -L https://foundry.paradigm.xyz \| bash && foundryup` |
| MetaMask | любая | https://metamask.io/ |
| ETH на Arbitrum Sepolia | ~0.01 ETH | Фаусет: https://faucet.quicknode.com/arbitrum/sepolia |

---

## 2. Сборка и тесты (смарт-контракты)

```bash
cd BlockChain2_Final

# Установка Solidity-зависимостей (OpenZeppelin, forge-std)
~/.foundry/bin/forge install

# Сборка контрактов
~/.foundry/bin/forge build

# Запуск всех 266 тестов (unit + fuzz + invariant + fork + security)
~/.foundry/bin/forge test
```

Или через Makefile:

```bash
make build
make test
```

---

## 3. Запуск фронтенда

```bash
cd frontend
npm install
npm run dev
```

Откроется на **http://localhost:5174** (или :5173).

Файл `frontend/.env` уже содержит адреса задеплоенных контрактов и URL субграфа — менять ничего не нужно.

---

## 4. Подключение кошелька

1. Открыть http://localhost:5174 в браузере с MetaMask
2. Нажать **Connect Wallet** → выбрать MetaMask
3. Если сеть не Arbitrum Sepolia — появится кнопка **Switch to Arbitrum Sepolia**, нажать её
4. Подтвердить переключение сети в MetaMask

---

## 5. Получение тестовых токенов

Из **корня проекта** (не из `frontend/`):

```bash
make seed-tokens WALLET=0xВАШ_АДРЕС_ИЗ_METAMASK
```

Это выдаст **10,000 USDC** и **10,000 IDAO** на ваш кошелёк.

> Если `make` недоступен:
> ```bash
> SEED_WALLET=0xВАШ_АДРЕС ~/.foundry/bin/forge script script/SeedTestTokens.s.sol \
>   --rpc-url https://sepolia-rollup.arbitrum.io/rpc --broadcast -vvvv
> ```

Балансы обновятся в шапке сайта автоматически (обновление каждые 4 секунды).

---

## 6. Тестирование функций через UI

### Шаг 1: Governance (делегирование)
1. Вкладка **Governance**
2. Нажать **Delegate to Myself** → подтвердить в MetaMask
3. Теперь у вас есть voting power

### Шаг 2: Underwrite (депозит коллатерала)
1. Вкладка **Underwrite**
2. Ввести сумму, например `1000`
3. **Approve USDC** → подтвердить в MetaMask
4. **Deposit Collateral** → подтвердить
5. Позиция появится на Dashboard

### Шаг 3: Insure (покупка полиса)
1. Вкладка **Insure**
2. Policy Type: `0`, Coverage: `100`, Duration: `30` дней
3. **Approve** → подтвердить
4. **Purchase Policy** → подтвердить

### Шаг 4: Dashboard
- Показывает vault shares, коллатерал, exposure, health factor
- Данные обновляются автоматически каждые 4 секунды

---

## 7. Деплой контрактов (НЕ обязательно)

Все контракты **уже задеплоены** и полностью функциональны. Команда ниже нужна **только** если вы хотите полностью передеплоить протокол с нуля на новые адреса:

```bash
make deploy-arbitrum
```

**Внимание:** после повторного деплоя нужно обновить все адреса в `frontend/.env`, пересобрать субграф и перенастроить policy types. Без этого фронтенд перестанет работать.

Для обычной проверки и тестирования проекта эта команда **не нужна**.

---

## 8. Субграф (The Graph)

Субграф уже задеплоен и подключён к фронтенду. Данные из него отображаются на Dashboard (статистика протокола) и на странице Underwrite.

Если нужно пересобрать/передеплоить субграф:

```bash
cd subgraph
npm install
npx graph codegen
npx graph build
npx graph deploy final
```

---

## 9. Полезные команды

| Команда | Описание |
|---------|----------|
| `make test` | Запуск всех тестов (266 шт.) |
| `make build` | Сборка контрактов |
| `make coverage` | Отчёт покрытия тестами |
| `make gas-report` | Gas-бенчмарки |
| `make slither` | Статический анализ безопасности |
| `make verify-deployment` | Проверка конфигурации деплоя |
| `make upgrade-v2` | Апгрейд InsurancePool до V2 |
| `make seed-tokens WALLET=0x...` | Выдать тестовые токены |

---

## 10. Структура проекта

```
BlockChain2_Final/
├── src/                  # Смарт-контракты (Solidity 0.8.24)
│   ├── InsurancePool.sol            # Главный контракт (UUPS proxy)
│   ├── InsurancePoolV2.sol          # V2 апгрейд
│   ├── UnderwriterVault.sol         # ERC-4626 хранилище
│   ├── CollateralManager.sol        # Коллатерал и ликвидации
│   ├── GovernanceToken.sol          # IDAO токен (ERC-20 + Votes)
│   ├── PolicyNFT.sol                # ERC-1155 полисы
│   ├── PolicyFactory.sol            # Фабрика (CREATE + CREATE2)
│   ├── ChainlinkOracleAdapter.sol   # Адаптер Chainlink оракула
│   ├── governance/                  # Governor + Treasury
│   ├── libraries/                   # PremiumMath (Yul assembly)
│   ├── vulnerable/                  # Кейс-стади уязвимостей
│   └── interfaces/                  # Интерфейсы
├── test/                 # 266 тестов
│   ├── fuzz/             # Фаз-тесты (27 шт.)
│   ├── invariant/        # Инвариантные тесты (5 шт.)
│   ├── fork/             # Форк-тесты Arbitrum (7 шт.)
│   ├── security/         # Кейс-стади безопасности
│   ├── governance/       # Тесты управления
│   └── mocks/            # Моки (MockERC20, MockAggregator)
├── script/               # Скрипты деплоя
├── frontend/             # React + Vite + Wagmi v2
├── subgraph/             # The Graph (AssemblyScript)
├── docs/                 # Документация
│   ├── architecture.md   # Архитектура, C4, ADR
│   └── audit-report.md   # Аудит безопасности
└── reports/              # Покрытие, газ
```

---

## Задеплоенные контракты (Arbitrum Sepolia)

| Контракт | Адрес | Arbiscan |
|----------|-------|----------|
| InsurancePool (Proxy) | `0xF293eD1ABd74D70A012c69b15f22C20Df4c8858C` | [Смотреть](https://sepolia.arbiscan.io/address/0xF293eD1ABd74D70A012c69b15f22C20Df4c8858C) |
| UnderwriterVault | `0xB0Cb5ECf100d8668A250118e64D6DA7f728E4865` | [Смотреть](https://sepolia.arbiscan.io/address/0xB0Cb5ECf100d8668A250118e64D6DA7f728E4865) |
| CollateralManager | `0xaAa36a7DEb22fdd9e3A5613f378405655cACc7bA` | [Смотреть](https://sepolia.arbiscan.io/address/0xaAa36a7DEb22fdd9e3A5613f378405655cACc7bA) |
| PolicyNFT | `0xa3Fc2415c383c58f5f27FcE5f1d26Cc54Dc9cEa6` | [Смотреть](https://sepolia.arbiscan.io/address/0xa3Fc2415c383c58f5f27FcE5f1d26Cc54Dc9cEa6) |
| GovernanceToken (IDAO) | `0xb06eCBf6dC4Ca68716b400bfC1Aacbae0d7e487f` | [Смотреть](https://sepolia.arbiscan.io/address/0xb06eCBf6dC4Ca68716b400bfC1Aacbae0d7e487f) |
| InsuranceGovernor | `0xD01F3b6e16828628746e0C6Be4258B81572ba549` | [Смотреть](https://sepolia.arbiscan.io/address/0xD01F3b6e16828628746e0C6Be4258B81572ba549) |
| TimelockController | `0x47089891c1a1e62A0bD880949fEa592056237970` | [Смотреть](https://sepolia.arbiscan.io/address/0x47089891c1a1e62A0bD880949fEa592056237970) |
| InsuranceTreasury | `0x032E146D35a5D643A18Deac4C3166592aCf1dB70` | [Смотреть](https://sepolia.arbiscan.io/address/0x032E146D35a5D643A18Deac4C3166592aCf1dB70) |
| MockUSDC | `0x0F5730CdDE59df09b142072B9C9b5e4a1e894a7C` | [Смотреть](https://sepolia.arbiscan.io/address/0x0F5730CdDE59df09b142072B9C9b5e4a1e894a7C) |
| PolicyFactory | `0xDcDd4c95a9c16C259E1f1c5824F65D0A32e89714` | [Смотреть](https://sepolia.arbiscan.io/address/0xDcDd4c95a9c16C259E1f1c5824F65D0A32e89714) |
