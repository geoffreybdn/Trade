# Stratégie d'exemple : croisement de moyennes mobiles (EMA) filtré par le RSI.
# C'est un point de départ pédagogique, PAS une stratégie rentable garantie.
# Teste-la toujours en backtest puis en dry-run avant de mettre de l'argent réel.

from pandas import DataFrame
import talib.abstract as ta

from technical import qtpylib
from freqtrade.strategy import IStrategy, IntParameter


class EmaRsiStrategy(IStrategy):
    INTERFACE_VERSION = 3

    timeframe = "1h"
    can_short = False  # spot uniquement

    # Prise de profit selon la durée du trade (minutes -> % de gain)
    minimal_roi = {
        "0": 0.06,
        "240": 0.03,
        "720": 0.01,
    }

    # Stop-loss à -5 %, avec trailing stop une fois +2 % atteint
    stoploss = -0.05
    trailing_stop = True
    trailing_stop_positive = 0.01
    trailing_stop_positive_offset = 0.02
    trailing_only_offset_is_reached = True

    process_only_new_candles = True
    startup_candle_count = 200

    # Paramètres optimisables avec `freqtrade hyperopt`
    ema_fast = IntParameter(5, 30, default=12, space="buy")
    ema_slow = IntParameter(20, 100, default=26, space="buy")
    rsi_entry_max = IntParameter(50, 75, default=65, space="buy")
    rsi_exit_min = IntParameter(65, 90, default=75, space="sell")

    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        for period in set(self.ema_fast.range) | set(self.ema_slow.range):
            dataframe[f"ema_{period}"] = ta.EMA(dataframe, timeperiod=period)
        dataframe["ema_200"] = ta.EMA(dataframe, timeperiod=200)
        dataframe["rsi"] = ta.RSI(dataframe, timeperiod=14)
        return dataframe

    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        fast = dataframe[f"ema_{self.ema_fast.value}"]
        slow = dataframe[f"ema_{self.ema_slow.value}"]
        dataframe.loc[
            (
                qtpylib.crossed_above(fast, slow)
                & (dataframe["close"] > dataframe["ema_200"])  # tendance haussière de fond
                & (dataframe["rsi"] < self.rsi_entry_max.value)  # pas déjà suracheté
                & (dataframe["volume"] > 0)
            ),
            "enter_long",
        ] = 1
        return dataframe

    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        fast = dataframe[f"ema_{self.ema_fast.value}"]
        slow = dataframe[f"ema_{self.ema_slow.value}"]
        dataframe.loc[
            (
                (qtpylib.crossed_below(fast, slow) | (dataframe["rsi"] > self.rsi_exit_min.value))
                & (dataframe["volume"] > 0)
            ),
            "exit_long",
        ] = 1
        return dataframe
