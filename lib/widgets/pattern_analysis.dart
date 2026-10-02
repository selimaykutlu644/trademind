import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class PatternAnalysis extends StatelessWidget {
  final Map<String, dynamic>? chartData;
  
  const PatternAnalysis({super.key, this.chartData});

  @override
  Widget build(BuildContext context) {
    if (chartData == null) {
      return const SizedBox.shrink();
    }

    final candlestick = chartData!['candlestick'] as Map<String, dynamic>?;
    final bollinger = chartData!['bollinger'] as Map<String, dynamic>?;
    final fisher = chartData!['fisher'] as Map<String, dynamic>?;
    final doublePattern = chartData!['doublePattern'] as Map<String, dynamic>?;
    final sr = chartData!['supportResistance'] as Map<String, dynamic>?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xff0c1327),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xff202b43)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'candlestick_patterns'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (candlestick != null) _buildCandlestickCard(candlestick),
          if (bollinger != null) _buildBollingerCard(bollinger),
          if (fisher != null) _buildFisherCard(fisher),
          if (doublePattern != null) _buildDoublePatternCard(doublePattern),
          if (sr != null) _buildSupportResistanceCard(sr),
        ],
      ),
    );
  }

  Widget _buildCandlestickCard(Map<String, dynamic> data) {
    final pattern = data['pattern'] as String? ?? 'unknown';
    final signal = data['signal'] as String? ?? 'neutral';
    final strength = (data['strength'] as num?)?.toDouble() ?? 0.0;

    String patternKey = 'pattern_$pattern';
    String patternName = patternKey.tr();
    if (patternName == patternKey) patternName = pattern;

    Color signalColor = signal == 'bullish' 
        ? const Color(0xff46dba7) 
        : signal == 'bearish' 
            ? const Color(0xffff7886) 
            : const Color(0xff97a7c3);

    return Card(
      color: const Color(0xff050816),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              signal == 'bullish' ? Icons.trending_up : signal == 'bearish' ? Icons.trending_down : Icons.remove,
              color: signalColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patternName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${'signal'.tr()}: ${signal.toUpperCase()} · ${'strength'.tr()}: ${(strength * 100).toInt()}%',
                    style: const TextStyle(
                      color: Color(0xff97a7c3),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBollingerCard(Map<String, dynamic> data) {
    final bandwidth = (data['bandwidth'] as num?)?.toDouble();
    final lastClose = (data['lastClose'] as num?)?.toDouble();
    final upper = (data['upper'] as num?)?.toDouble();
    final lower = (data['lower'] as num?)?.toDouble();

    String status = 'neutral';
    if (lastClose != null && upper != null && lastClose >= upper) {
      status = 'bollinger_upper_touch';
    } else if (lastClose != null && lower != null && lastClose <= lower) {
      status = 'bollinger_lower_touch';
    } else if (bandwidth != null && bandwidth < 0.02) {
      status = 'bollinger_squeeze';
    } else if (bandwidth != null && bandwidth > 0.04) {
      status = 'bollinger_expansion';
    }

    return Card(
      color: const Color(0xff050816),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'bollinger_bands'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '${status.tr()} · Bandwidth: ${bandwidth != null ? (bandwidth * 100).toStringAsFixed(2) : 'N/A'}%',
              style: const TextStyle(
                color: Color(0xff97a7c3),
                fontSize: 12,
              ),
            ),
            if (upper != null && lower != null)
              Text(
                'Range: ${lower.toStringAsFixed(2)} - ${upper.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xff97a7c3),
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFisherCard(Map<String, dynamic> data) {
    final signal = data['signal'] as String? ?? 'neutral';
    final current = (data['current'] as num?)?.toDouble();

    return Card(
      color: const Color(0xff050816),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              signal == 'buy' ? Icons.arrow_upward : signal == 'sell' ? Icons.arrow_downward : Icons.remove,
              color: signal == 'buy' 
                  ? const Color(0xff46dba7) 
                  : signal == 'sell' 
                      ? const Color(0xffff7886) 
                      : const Color(0xff97a7c3),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'fisher_transform'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${signal == 'buy' ? 'fisher_signal_buy' : signal == 'sell' ? 'fisher_signal_sell' : 'neutral'.tr()} · Value: ${current?.toStringAsFixed(3) ?? 'N/A'}',
                    style: const TextStyle(
                      color: Color(0xff97a7c3),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoublePatternCard(Map<String, dynamic> data) {
    final pattern = data['pattern'] as String? ?? 'unknown';
    final signal = data['signal'] as String? ?? 'neutral';
    final level = (data['level'] as num?)?.toDouble();

    String patternKey = 'double_${pattern == 'double_top' ? 'top' : 'bottom'}';
    String patternName = patternKey.tr();
    if (patternName == patternKey) patternName = pattern;

    return Card(
      color: const Color(0xff050816),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              signal == 'bullish' ? Icons.trending_up : Icons.trending_down,
              color: signal == 'bullish' 
                  ? const Color(0xff46dba7) 
                  : const Color(0xffff7886),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patternName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Level: ${level?.toStringAsFixed(2) ?? 'N/A'}',
                    style: const TextStyle(
                      color: Color(0xff97a7c3),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportResistanceCard(Map<String, dynamic> data) {
    final support = data['support'] as List<dynamic>?;
    final resistance = data['resistance'] as List<dynamic>?;
    final nearestSupport = data['nearestSupport'] as num?;
    final nearestResistance = data['nearestResistance'] as num?;

    return Card(
      color: const Color(0xff050816),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'support_resistance'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (nearestSupport != null)
              _buildLevelRow('nearestSupport'.tr(), nearestSupport, const Color(0xff46dba7)),
            if (nearestResistance != null)
              _buildLevelRow('nearestResistance'.tr(), nearestResistance, const Color(0xffff7886)),
            if (support != null && support.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'major_support'.tr(),
                style: const TextStyle(
                  color: Color(0xff97a7c3),
                  fontSize: 11,
                ),
              ),
              ...support.take(3).map((s) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text(
                  (s as num).toStringAsFixed(2),
                  style: const TextStyle(
                    color: Color(0xff46dba7),
                    fontSize: 12,
                  ),
                ),
              )),
            ],
            if (resistance != null && resistance.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'major_resistance'.tr(),
                style: const TextStyle(
                  color: Color(0xff97a7c3),
                  fontSize: 11,
                ),
              ),
              ...resistance.take(3).map((r) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text(
                  (r as num).toStringAsFixed(2),
                  style: const TextStyle(
                    color: Color(0xffff7886),
                    fontSize: 12,
                  ),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLevelRow(String label, num value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xff97a7c3),
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}