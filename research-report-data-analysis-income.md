# Data Analysis & Prediction Income Report for Sean Cairns

**Prepared:** July 27, 2026
**Context:** MSc Big Data Technologies student (Glasgow Caledonian University), summer break until Sep 2026, based in Dripping Springs, TX
**Key Constraints:** Minimal human interaction, remote-only, part-time, leverages data science + infrastructure skills

---

## Top 3 Recommendations — Summary Table

| # | Option | Upfront Cost | Time to First $ | Monthly Potential | Interaction | Risk |
|---|--------|-------------|-----------------|-------------------|-------------|------|
| 1 | Numerai Tournament | $0 (paper) / ~$100-500 (staked) | 4-8 weeks | $0-$2,000+ | **None** | Medium |
| 2 | AWS Data Exchange (Dataset Products) | ~$50-100/mo (AWS infra) | 4-12 weeks | $0-$3,000+ | **Very Low** | Low-Med |
| 3 | Automated Sports Prediction Models | $0 (public data) / ~$100-200 (API data) | 6-12 weeks | $0-$1,500+ | **None** | Medium |

---

## Recommendation #1: Numerai Tournament

### What It Is

Numerai is a crowdsourced hedge fund that pays data scientists to build machine learning models that predict stock market movements. It's a weekly tournament where you train ML models on Numerai's obfuscated financial dataset and submit predictions. If your model outperforms, you earn NMR cryptocurrency tokens (currently ~$8.66 each). You can optionally "stake" NMR tokens on your model to amplify earnings — but this is optional; you can paper-trade first risk-free.

**Why this is the #1 pick:** It requires *zero* human interaction. No clients, no meetings, no freelancing platforms. You just build models, submit predictions, and collect rewards. It directly applies your upcoming AI & Machine Learning coursework and your existing Python/data science skills.

### How It Uses Your Skills

- **Machine Learning** (your upcoming coursework): Build regression/classification models using XGBoost, neural networks, or ensemble methods — exactly what you'll study in AI & ML starting Sep 2026
- **Python**: The platform is Python-native (example scripts in pandas, scikit-learn, XGBoost, PyTorch, TensorFlow)
- **Infrastructure (NixOS)**: Automate model training/submission via cron jobs on your Linux infrastructure — many top participants run fully automated pipelines
- **Data Visualisation** (completed course): Analyze your model performance across "eras" (time periods)
- **Big Data Platforms** (completed course): Handle the dataset (train.parquet is ~1-2GB, tournament data is manageable on a single machine)

### Earning Potential

| Level | Monthly (USD) | Description |
|-------|--------------|-------------|
| **Low** (first 3 months, paper trading) | $0 | Learning the platform, building track record |
| **Medium** (months 3-6, small stake ~$200) | $50-$300/mo | 19.19% average annual return on staked NMR, plus NMR price appreciation |
| **High** (6-12 months, experienced, $1K+ stake) | $500-$2,500+/mo | Top quartile performers earn 40-100%+ annual returns on stake |

**Current leaderboard data (July 2026):**
- 2,590 total data scientists, 641 actively staked
- 740,497 NMR total staked (~$6.4M at $8.66/NMR)
- Average 1Y return: **19.19%**
- Top 10 performers: 50-103% annual return
- NMR token price history: ATH $93.15 (2021), current $8.66, so there's upside potential if the hedge fund's JPMorgan partnership gains traction

**Realistic scenario for a student:** Stake $200-500 worth of NMR ($1,730-$4,330 at current prices). If your model performs at the average 19% return, that's ~$38-95/month in token earnings, plus potential token appreciation. If you perform in top quartile, expect $80-500/month.

### Time to First Payout

- **Week 1**: Set up account, download data, train baseline model → submit first predictions (ungraded initially)
- **Weeks 2-4**: Iterate on model, build track record
- **Week 4-6**: If track record is positive, stake small NMR amount
- **Week 6-8**: First payout (payouts occur weekly after rounds settle)
- **Total: ~4-8 weeks to first payout**

### Required Tools & Platforms

| Tool | Purpose | Cost |
|------|---------|------|
| Numerai account (numer.ai) | Tournament platform | Free |
| Python 3.9+ | Model development | Free |
| scikit-learn, XGBoost, LightGBM | ML libraries | Free |
| PyTorch or TensorFlow | Deep learning (optional) | Free |
| pandas, numpy, matplotlib | Data manipulation & analysis | Free |
| Coinbase account | Buy NMR tokens (when ready to stake) | Free to open |
| Ethereum wallet (MetaMask/Privy) | Store NMR tokens | Free |
| Numerai CLI | Automate submissions | Free |
| Cron/systemd timer (on your NixOS infra) | Automated weekly submission | Free (you have this) |
| GPU (optional but helpful) | Faster model training | Your existing hardware ($0) |

### Key Steps to Start (First 30 Days)

- **Day 1-3:** Sign up at numer.ai, read the docs (docs.numer.ai/tournament/learn), clone the example-scripts repo
- **Day 3-7:** Run the example XGBoost model locally, make your first submission (predictions.csv upload)
- **Day 7-14:** Explore the data, understand eras and features, read the scoring docs (CORR, MMC, FNC)
- **Day 14-21:** Iterate on models — try different algorithms, feature engineering approaches, hyperparameter tuning
- **Day 21-28:** Automate your pipeline — set up a weekly cron/systemd timer on your NixOS server to auto-download data, train, and submit via Numerai CLI
- **Day 28-30:** Evaluate your 4-week track record. If positive, buy ~$100 worth of NMR on Coinbase and stake a small amount

### Social Interaction Level: **NONE**

- No meetings, no calls, no clients
- All communication is via Discord (optional, anonymous) or forum
- You can participate completely anonymously
- The platform handles all the financial operations

### Risks & Challenges

1. **Model performance is uncertain** — you could submit for months with negative returns (hence the "paper trade first" advice)
2. **NMR token volatility** — NMR is a cryptocurrency and has dropped 90% from its ATH; your staked value can fluctuate with market conditions, not just model performance
3. **Overfitting risk** — Numerai data is designed to be tricky; models that look good on validation can fail on live data
4. **No guaranteed income** — this is not a salary; some weeks you may earn nothing or lose staked tokens
5. **Crypto tax implications** — NMR earnings are taxable as income in the US; you'll need to track your earnings and report them
6. **Payout factor is dynamic** — as more people stake, the payout factor decreases (currently 0.09x per round)
7. **Time commitment** — serious participants spend 5-15 hours/week building and refining models

### Links & References

| Resource | URL |
|----------|-----|
| Numerai Tournament | https://numer.ai |
| Documentation | https://docs.numer.ai/tournament/learn |
| Example Scripts | https://github.com/numerai/example-scripts |
| Leaderboard | https://numer.ai/leaderboard |
| Latest Round | https://numer.ai/round/latest |
| NMR on CoinGecko | https://www.coingecko.com/en/coins/numeraire |
| NMR on Coinbase | https://www.coinbase.com/price/numeraire |
| Discord Community | https://discord.gg/numerai |
| Forum | https://forum.numer.ai |
| Get API Keys | https://numer.ai/signup |

---

## Recommendation #2: AWS Data Exchange — Sell Niche Datasets

### What It Is

AWS Data Exchange is a marketplace (3,500+ existing products, 100+ petabytes of data) where data providers sell datasets to AWS customers (enterprises, data scientists, researchers). You identify a data gap, build/crawl/curate a clean, well-documented dataset in a niche domain, package it as Parquet/CSV files on S3, and list it as a subscription product (1-36 month terms). AWS handles billing, delivery, entitlement, and discoverability. You retain full ownership of the data.

**Why this fits your profile:** You have the infrastructure skills (NixOS, cloud computing from your completed Cloud Computing & Web Services course) to run automated data collection pipelines. You have the data skills to clean, validate, and document datasets. And you have the Big Data Platforms knowledge to use tools like Spark, Athena, or Glue for ETL. Once the dataset is listed, it generates passive income with zero ongoing interaction.

### How It Uses Your Skills

- **Cloud Computing & Web Services** (completed course): Deploy data pipeline on AWS (EC2, S3, Lambda, CloudWatch) to collect and update data automatically. Use your existing NixOS infra to manage these deployments.
- **Big Data Platforms** (completed course): Process large datasets using Parquet format, partition data for efficient querying
- **Data Visualisation** (completed course): Create sample dashboards and data previews for your product listing
- **IoT** (completed course): Potential niche — IoT/sensor data is in high demand
- **NixOS infrastructure skills**: Automate the entire pipeline with Nix (declarative, reproducible, cronned)

### Earning Potential

| Level | Monthly (USD) | Description |
|-------|--------------|-------------|
| **Low** (first 3 months, building) | $0 | Building pipeline, creating first dataset |
| **Medium** (one product, 3-10 subscribers) | $100-$500/mo | Pricing at $50-200/month per subscription |
| **High** (2-3 products, 10-50 subscribers) | $500-$3,000+/mo | Multiple niche datasets with recurring subscriptions |

**Real-world examples from AWS Data Exchange catalog:**
- Weather data providers charge $50-$500/month for historical/forecast data
- Financial data (stock fundamentals, sentiment scores) goes for $100-$1,000+/month
- Geospatial/environmental datasets: $50-$300/month
- Niche industry data (real estate comps, restaurant inspection scores, solar irradiance): $30-$200/month

**Realistic for a student:** Price your first dataset at $49-99/month. If you get 5-15 enterprise subscribers within 6 months, that's $245-$1,485/month recurring. AWS takes a tiered fulfillment fee (typically 15-20%).

### Time to First Payout

- **Weeks 1-2**: Identify a data niche, validate demand, ensure you have legal right to distribute the data
- **Weeks 2-6**: Build the data collection pipeline (scraping, API collection, data cleaning, Parquet conversion)
- **Weeks 4-6**: Set up AWS infrastructure (S3 buckets, automated updates via Lambda/EC2/cron)
- **Weeks 6-8**: Register as AWS Marketplace seller (requires US legal entity — your LLC or individual tax ID)
- **Weeks 6-10**: Publish product, configure pricing and Data Subscription Agreement
- **Weeks 8-16**: First subscribers → first monthly payout (AWS disburses monthly)
- **Total: ~8-16 weeks to first payout**

### Required Tools & Platforms

| Tool | Purpose | Cost |
|------|---------|------|
| AWS Account | Host data on S3, use Lambda/EC2 for pipeline | ~$50-100/mo for storage + compute |
| AWS Data Exchange | Marketplace to sell data | Free (revenue share only) |
| Python + pandas | Data cleaning, transformation | Free |
| Apache Parquet | Efficient data format | Free |
| AWS CLI / boto3 | Automate data uploads | Free |
| Scrapy or BeautifulSoup | Web scraping (if applicable) | Free |
| Public APIs | Data sources (free tier) | Free |
| Register as AWS Marketplace Seller | Legal/tax setup | Free (but requires US/EU entity) |
| Your NixOS infra | Run automated collection pipeline | You already have this |

### Key Steps to Start (First 30 Days)

- **Week 1:** Research the AWS Data Exchange catalog — find gaps where demand exceeds supply. Look at what financial, weather, geospatial, or industry-specific datasets are selling well. Identify a specific niche you can serve (e.g., Texas-specific solar irradiance data, restaurant inspection scores by county, local real estate market comps, or curated public financial filings for small-cap companies).
- **Week 1-2:** Verify you can legally collect and redistribute the data. If using public APIs, check terms of service.
- **Week 2-3:** Build a minimum viable dataset (1 month of data, clean, documented, in Parquet format).
- **Week 3-4:** Set up your AWS infrastructure — S3 bucket with proper partitioning, automated data refresh pipeline using your NixOS machine to run daily/weekly collection jobs.
- **Week 3-4:** Register as an AWS Marketplace seller (this takes a few days for approval — they verify your legal entity).
- **Week 4:** Create your product listing with clear documentation, sample data, and pricing. Publish.
- **First dataset niche ideas:**
  - **Texas-specific environmental data** (solar, weather, water levels) — you're in Texas, this is locally relevant
  - **Curated SEC filings for ML training** — structured financial narrative data
  - **Public transit/transportation data** cleaned and normalized
  - **NixOS package statistics** — number of package updates, CVEs, build times
  - **Local government data** cleaned and aggregated (property assessments, permits, inspections)

### Social Interaction Level: **VERY LOW**

- No face-to-face or voice interaction
- You'll need to respond to subscriber support inquiries via email within 1 business day (AWS Data Exchange requires this)
- Product description and documentation are written once
- You can handle everything via email/async

### Risks & Challenges

1. **Legal/data rights** — you must have clear rights to distribute the data. Public APIs may prohibit resale. Scraping may violate ToS.
2. **Demand uncertainty** — no guarantee anyone will subscribe. You need to validate demand before building.
3. **AWS marketplace seller requirements** — requires a US or EU legal entity (LLC, sole proprietorship, or corporation). You'll need to set up a business bank account and tax ID.
4. **Ongoing maintenance** — data must be kept fresh. If you publish a "daily update" dataset, you need your pipeline running 24/7.
5. **Revenue share** — AWS takes a cut (tiered fulfillment fees, typically 15-20% of revenue).
6. **Competition** — some niches are saturated. You need to find a unique angle or underserved market.

### Links & References

| Resource | URL |
|----------|-----|
| AWS Data Exchange | https://aws.amazon.com/data-exchange/ |
| Become a Provider | https://aws.amazon.com/data-exchange/faqs/ |
| AWS Marketplace Seller Registration | https://aws.amazon.com/marketplace/management/register/ |
| Data Exchange Catalog (browse) | https://aws.amazon.com/marketplace/search/results?category=d5a43d97-558f-4be7-8543-cce265fe6d9d |
| Pricing for Providers | https://aws.amazon.com/data-exchange/pricing/ |
| Publishing Guide | https://docs.aws.amazon.com/data-exchange/latest/userguide/publishing-products.html |
| AWS Free Tier | https://aws.amazon.com/free/ |

---

## Recommendation #3: Automated Sports Prediction Models (Subscription-Based)

### What It Is

Build a fully automated system that collects sports data, runs ML prediction models, and publishes daily predictions/subscriptions. You sell access to your predictions via a simple subscription model (Substack, Gumroad, or your own Stripe-powered site). The models predict game outcomes, player performance stats, or other quantifiable sports events.

**Important distinction:** You are NOT placing bets yourself or running a gambling service. You are selling data analysis and predictions as a product. Subscribers (bettors, fantasy players, sports analysts) use your predictions however they choose. This is legal and common — many successful data scientists run sports prediction services (e.g., numberFire, TeamRankings started as data projects).

**Why Texas is relevant:** Daily fantasy sports (DraftKings, FanDuel) are legal in Texas. Sports betting is NOT yet legal in Texas, but prediction analysis is information — it's a First Amendment protected service. Your subscribers can be anywhere sports betting is legal.

### How It Uses Your Skills

- **AI & Machine Learning** (upcoming coursework): Build models for predicting outcomes (classification), player performance (regression), and injury impact (NLP on news)
- **Data Visualisation** (completed course): Create compelling prediction dashboards and reports for subscribers
- **Big Data Platforms** (completed course): Process historical sports data at scale using Parquet/Spark
- **Cloud Computing** (completed course): Deploy daily automated pipeline on AWS or your own infrastructure
- **NixOS infrastructure**: Run cronned model training, prediction generation, and automated content publishing

### Earning Potential

| Level | Monthly (USD) | Description |
|-------|--------------|-------------|
| **Low** (first season, free tier + some subscribers) | $0-$100/mo | Building track record, proving model accuracy |
| **Medium** (1-2 sports, 50-200 subscribers) | $250-$1,000/mo | $5-10/month subscription × subscribers |
| **High** (3+ sports, 500+ subscribers) | $1,500-$5,000+/mo | Multiple subscription tiers, proven track record |

**Comparable services as reference:**
- Action Network premium: $9.99/month (but they have a team of analysts)
- Individual data scientists on Substack: $5-15/month, typically 50-500 subscribers
- Picks services (e.g., EV Analytics, BettingPros): $20-50/month for premium picks
- **Realistic solo operation:** Launch at $9.99/month. If your model proves accurate (55%+ against spread), you can grow to 100-300 subscribers within one season = $1,000-3,000/month

### Time to First Payout

- **Weeks 1-3**: Choose a sport and market (e.g., NFL against the spread, MLB moneyline, NBA totals). Collect historical data (5+ seasons). Build baseline prediction model.
- **Weeks 3-6**: Validate model on out-of-sample historical data. Iterate on features (team stats, injuries, weather, rest days, travel distance, etc.)
- **Weeks 6-8**: Backtest rigorously — document your model's hypothetical track record over past seasons.
- **Weeks 8-10**: Set up automated pipeline that generates predictions daily. Automate delivery (Substack/email, a simple website).
- **Weeks 8-12**: Launch with a free trial to build social proof. Start charging once you have some performance track record.
- **Total: ~8-12 weeks to first subscriber revenue**

### Required Tools & Platforms

| Tool | Purpose | Cost |
|------|---------|------|
| Sports data API (SportsRadar, The Odds API, MySportsFeeds) | Historical and live data | $100-200/mo for pro tier |
| Python + pandas/scikit-learn/XGBoost | Model development | Free |
| PyTorch/TensorFlow | Deep learning models (optional) | Free |
| PostgreSQL or SQLite | Store historical data | Free |
| Substack, Gumroad, or Ghost | Subscription/payment platform | Free-$10/mo |
| Stripe | Payment processing | 2.9% + $0.30 per transaction |
| Simple static site (Hugo/Zola) | Landing page and prediction display | Free (GitHub Pages) |
| Your NixOS infra | Run automated daily pipeline | You already have |
| Cron/systemd timer | Daily prediction generation | Free |

**Best sports data APIs (with cost):**
- **The Odds API** (the-odds-api.com) — Free tier (500 requests/month), paid $50/mo for more. Best for betting odds data.
- **SportsDataIO** — NFL/NBA/MLB/NHL data, $99-199/month for developer tier. Excellent but pricey.
- **MySportsFeeds** — $49/month for 1 sport, includes structured game data.
- **SportsReference.com** (fbref.com, baseball-reference.com) — Free to scrape (respect rate limits), but US age 21+ only.
- **Free alternative:** Scrape ESPN, CBS Sports, or use NCAA public data for college sports (free).

### Key Steps to Start (First 30 Days)

- **Week 1:** Choose your sport. **Recommendation: NBA** (frequent games, lots of data, well-studied, easier to find an edge) or **MLB** (162-game season = lots of data points). NFL has fewer games (17 per team) so harder to validate models quickly.
- **Week 1-2:** Pick your prediction target. "Against the spread" (ATS) is the most marketable. Or pick something niche like "NBA first quarter totals" where fewer analysts focus.
- **Week 2-3:** Scrape/download 5+ seasons of historical data. Build feature engineering pipeline:
  - Team stats (offensive/defensive ratings, pace, rebounding, turnovers)
  - Rest days, travel distance, altitude
  - Recent form (last 5-10 games)
  - Head-to-head history
  - Public betting percentages (if available)
- **Week 3-4:** Build baseline XGBoost or logistic regression model. Backtest over 3+ seasons. Track accuracy against the spread (55%+ is strong, 60% is elite).
- **Week 4:** Set up automated pipeline on your NixOS machine using cron — daily data fetch, model retrain, prediction generation.
- **First 30 days output:** A working backtested model for NBA/MLB with a documented 3-year track record. This track record IS your marketing asset.

### Social Interaction Level: **NONE** (after setup)

- Everything is automated — no client calls, no meetings
- Predictions delivered via automated email (Substack) or auto-published to a static site
- You can optionally run a Twitter bot that auto-posts predictions (zero interaction)
- You never need to talk to subscribers — they pay and receive predictions
- Support can be handled via FAQ/automated responses

### Risks & Challenges

1. **No guarantee of model accuracy** — sports prediction is notoriously hard. 55% ATS accuracy over a season is considered excellent. You need to set realistic expectations.
2. **Data costs** — quality sports data APIs cost $50-200/month, which you need to cover before you have subscribers
3. **Seasonality** — predictions only generate revenue during the season (NBA: Oct-June, MLB: Mar-Oct, NFL: Sep-Feb). You need to plan for off-season.
4. **Legal gray area** — while selling predictions/information is protected speech, some platforms (Patreon, Stripe) may have gambling-related policies. Use Substack (which allows sports analysis) or your own site.
5. **Regulatory risk** — Texas may legalize sports betting in the future (it's been proposed), which would open up more opportunities but also increase competition
6. **Competition is intense** — many people sell sports picks. You need a demonstrable edge (unique model, niche market, proven track record).
7. **Scalability plateau** — most solo sports prediction services top out at 200-500 subscribers without significant marketing effort

### Links & References

| Resource | URL |
|----------|-----|
| The Odds API (best starter API) | https://the-odds-api.com |
| SportsDataIO | https://sportsdata.io |
| MySportsFeeds | https://www.mysportsfeeds.com |
| Substack (subscription platform) | https://substack.com |
| Sports Reference (free data) | https://www.sports-reference.com |
| NBA Stats API (free) | https://github.com/swar/nba_api |
| Kaggle Sports Datasets | https://www.kaggle.com/search?q=sports |
| Backtesting Framework (sports-betting) | https://github.com/georgemarsden/sports-betting |

---

## Bonus: What to Avoid

These come up often in searches but are NOT recommended for your situation:

| Option | Why Avoid |
|--------|-----------|
| Upwork / Fiverr data analysis freelancing | Requires client communication, bidding, revisions — high interaction |
| Teaching data science (Udemy/Coursera) | High interaction, requires content creation, crowded market |
| MLM data "consulting" schemes | They're MLMs |
| Crypto trading bots | Spectacular failure rate, regulatory risk |
| Academic data entry/labeling | Low pay ($5-15/hr), mind-numbing, no skill growth |
| Starting a data science blog/YouTube | Takes 6-18 months to monetize, requires constant content creation |

---

## Dissertation Synergy — Recommended Approach

All three options above can feed directly into your upcoming dissertation (Jan-May 2027):

1. **Numerai** → Dissertation on "Ensemble Methods for Financial Prediction Under Feature Obfuscation" or "Meta-Learning for Time Series Prediction in Crowdsourced Hedge Fund Environments"
2. **AWS Data Exchange** → Dissertation on "Automated Data Curation Pipelines for Machine Learning Training Datasets" or "Designing a Scalable Data Product Marketplace Infrastructure"
3. **Sports Prediction** → Dissertation on "Feature Engineering and Model Selection for Sports Outcome Prediction" or "Comparative Analysis of Machine Learning Approaches for Against-the-Spread Prediction"

The Numerai route has the strongest dissertation potential because:
- Numerai's data is real, anonymized financial data — exactly what Big Data/AI research looks at
- You could publish findings on model comparison, feature importance analysis, or ensemble strategies
- Numerai's API allows you to store your full submission history for analysis
- The research question ("how do we predict under obfuscation?") is genuinely novel

---

## Recommended First Steps (Right Now, This Week)

Given you're on summer break with free time, here's the optimal launch sequence:

1. **This week:** Sign up for Numerai (numer.ai) and clone the example scripts. Run the baseline XGBoost model. Make your first submission. This takes 2-3 hours and costs nothing.
2. **Next week:** While your first Numerai predictions are scoring, research AWS Data Exchange niches. Identify one specific dataset gap.
3. **Week 3:** Start building your data pipeline for whichever dataset you identified. Parallel track: iterate on your Numerai model.
4. **By end of summer (Sep 2026):** You should have: (a) 8+ weeks of Numerai track record, (b) a dataset ready to list on AWS Data Exchange, and (c) a clear plan for which option to scale during the academic year.

**The recommended path:** Focus on Numerai. It has the lowest barrier to entry, zero social interaction, and directly maps to your MSc curriculum. The dataset product is a good secondary project for passive income. Sports prediction is a viable third option if you have a specific sports interest.
