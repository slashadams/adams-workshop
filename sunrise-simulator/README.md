# Sunrise Simulator 🌅

Replicates natural morning light using Philips Hue. A 30-minute gradual ramp from warm orange (~2000K) to bright cool white (~5000K).

## Quick Start

```bash
# 1. Find your Hue bridge
python3 hue-sunrise.py --discover

# 2. Press the button on your Hue Bridge, then register
python3 hue-sunrise.py --register

# 3. See your lights
python3 hue-sunrise.py --list

# 4. Test a light (blinks twice)
python3 hue-sunrise.py --light 1 --test

# 5. Run the sunrise
python3 hue-sunrise.py --light 1
```

## Automation

Set up a cron job on your server to run at wake time:

```bash
# Example: 6:30 AM every weekday
30 6 * * 1-5 cd /path/to/sunrise-simulator && python3 hue-sunrise.py --light 1
```
