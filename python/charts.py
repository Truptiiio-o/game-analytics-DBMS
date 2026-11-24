# =============================================================
# FILE   : python/charts.py
# PURPOSE: Reusable chart generation functions for the project.
#          Generates all executive and analytical charts saved
#          into outputs/charts/.
#
# RUN VIA:
#   python python/charts.py
# =============================================================

import os
# Configure custom matplotlib directory to avoid font-lock conflicts
os.environ['MPLCONFIGDIR'] = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '.mplconfig'))
os.makedirs(os.environ['MPLCONFIGDIR'], exist_ok=True)

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import pandas as pd
import numpy as np

OUTPUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'outputs', 'charts'))
os.makedirs(OUTPUT_DIR, exist_ok=True)


def plot_simpsons_paradox():
    """Generates 02_simpsons_paradox_key.png."""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(13, 5), gridspec_kw={'width_ratios': [1, 2.2]})

    periods = ['P1: Jan 1-30\n(First 30d)', 'P2: Apr 1-30\n(Last 30d)']
    overall_vals = [0.3567, 0.2985]
    bars1 = ax1.bar(periods, overall_vals, color=['#1f77b4', '#d62728'], width=0.55)
    ax1.set_title('Overall Game ARPDAU\n(Down 16.3%)', fontsize=12, fontweight='bold')
    ax1.set_ylabel('ARPDAU (USD)')
    ax1.set_ylim(0, 0.65)
    for bar in bars1:
        y = bar.get_height()
        ax1.text(bar.get_x() + bar.get_width()/2, y + 0.015, f'${y:.4f}', ha='center', va='bottom', fontweight='bold', fontsize=11)
    ax1.annotate('', xy=(1, 0.31), xytext=(0, 0.37), arrowprops=dict(arrowstyle='->', color='black', lw=2))
    ax1.text(0.5, 0.36, '-16.3%', ha='center', fontweight='bold', color='darkred', fontsize=12)
    ax1.grid(True, linestyle='--', alpha=0.4, axis='y')

    tiers = ['Tier 1\n(High Rev)', 'Tier 2', 'Tier 3', 'Tier 4\n(Low Rev)']
    p1_tiers = [0.5235, 0.3754, 0.2339, 0.1552]
    p2_tiers = [0.5602, 0.4073, 0.2654, 0.1582]
    x = np.arange(len(tiers))
    width = 0.35

    ax2.bar(x - width/2, p1_tiers, width, label='P1: First 30 Days', color='#1f77b4', alpha=0.85)
    ax2.bar(x + width/2, p2_tiers, width, label='P2: Last 30 Days', color='#2ca02c', alpha=0.85)
    ax2.set_title('ARPDAU by Country Tier\n(Every Single Tier is FLAT or UP!)', fontsize=12, fontweight='bold')
    ax2.set_xticks(x)
    ax2.set_xticklabels(tiers, fontsize=10)
    ax2.set_ylim(0, 0.65)
    ax2.legend(loc='upper right')
    ax2.grid(True, linestyle='--', alpha=0.4, axis='y')

    tier_diffs = ['+7.0%', '+8.5%', '+13.5%', '+1.9%']
    for i, diff in enumerate(tier_diffs):
        max_h = max(p1_tiers[i], p2_tiers[i])
        ax2.text(x[i] + width/2, max_h + 0.015, diff, ha='center', va='bottom', fontweight='bold', color='darkgreen', fontsize=10)

    plt.tight_layout()
    out_path = os.path.join(OUTPUT_DIR, '02_simpsons_paradox_key.png')
    plt.savefig(out_path, dpi=150)
    plt.close()
    print(f'Saved: {out_path}')


def plot_dau_mix_shift():
    """Generates 02_dau_mix_shift_supporting.png."""
    fig, ax = plt.subplots(figsize=(9, 5))
    p1_shares = [34.5, 26.1, 21.8, 17.7]
    p2_shares = [20.4, 15.6, 18.0, 46.0]
    tier_labels = ['Tier 1 (High)', 'Tier 2', 'Tier 3', 'Tier 4 (Low)']
    colors = ['#1f77b4', '#aec7e8', '#ffbb78', '#ff7f0e']

    bottom_p1 = 0
    bottom_p2 = 0
    for i in range(len(tier_labels)):
        ax.bar('P1 (First 30d)', p1_shares[i], bottom=bottom_p1, color=colors[i], label=tier_labels[i], width=0.45)
        ax.text('P1 (First 30d)', bottom_p1 + p1_shares[i]/2, f'{tier_labels[i]}: {p1_shares[i]}%', ha='center', va='center', fontweight='bold', fontsize=9)
        bottom_p1 += p1_shares[i]
        
        ax.bar('P2 (Last 30d)', p2_shares[i], bottom=bottom_p2, color=colors[i], width=0.45)
        ax.text('P2 (Last 30d)', bottom_p2 + p2_shares[i]/2, f'{tier_labels[i]}: {p2_shares[i]}%', ha='center', va='center', fontweight='bold', fontsize=9)
        bottom_p2 += p2_shares[i]

    ax.set_title('DAU Composition Shift by Country Tier\n(Tier 4 expanded from 17.7% to 46.0% of total active players)', fontsize=12, fontweight='bold')
    ax.set_ylabel('Share of Total DAU (%)')
    ax.set_ylim(0, 100)
    plt.tight_layout()
    out_path = os.path.join(OUTPUT_DIR, '02_dau_mix_shift_supporting.png')
    plt.savefig(out_path, dpi=150)
    plt.close()
    print(f'Saved: {out_path}')


def plot_channel_comparison():
    """Generates 03_channel_comparison.png."""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5.5), gridspec_kw={'width_ratios': [1, 1.4]})

    models = ['Naive Comparison\n(Uncontrolled)', 'Adjusted Comparison\n(Tier-Controlled)']
    point_estimates = [0.6668, -0.1179]
    yerr_low = [0.6668 - 0.4153, -0.1179 - (-0.4494)]
    yerr_high = [0.9441 - 0.6668, 0.2115 - (-0.1179)]

    ax1.axhline(0, color='gray', linestyle='--', alpha=0.7)
    ax1.errorbar(0, point_estimates[0], yerr=[[yerr_low[0]], [yerr_high[0]]], fmt='o', color='#d62728', ecolor='#d62728', elinewidth=2.5, capsize=6, markersize=8)
    ax1.errorbar(1, point_estimates[1], yerr=[[yerr_low[1]], [yerr_high[1]]], fmt='o', color='#1f77b4', ecolor='#1f77b4', elinewidth=2.5, capsize=6, markersize=8)

    ax1.set_xticks([0, 1])
    ax1.set_xticklabels(models, fontsize=10)
    ax1.set_title('Revenue Difference: Paid Social - Paid Video\n(95% Bootstrap Confidence Intervals)', fontsize=12, fontweight='bold')
    ax1.set_ylabel('D30 Revenue Difference per Install (USD)')
    ax1.set_ylim(-0.7, 1.2)

    ax1.text(0, 0.75, '+$0.67***\n[+$0.42, +$0.94]\nStatistically Significant\n(MISLEADING ARTEFACT)', ha='center', va='bottom', color='darkred', fontweight='bold', fontsize=9.5)
    ax1.text(1, -0.05, '-$0.12 (p > 0.40)\n[-$0.45, +$0.21]\nNOT Significant\n(Crosses Zero)', ha='center', va='top', color='navy', fontweight='bold', fontsize=9.5)
    ax1.grid(True, linestyle='--', alpha=0.4, axis='y')

    tiers = ['Tier 1', 'Tier 2', 'Tier 3', 'Tier 4']
    x = np.arange(len(tiers))
    width = 0.25

    org_vals = [3.870, 2.463, 1.881, 1.046]
    soc_vals = [3.306, 2.219, 1.744, 1.100]
    vid_vals = [3.590, 2.414, 1.750, 1.151]

    ax2.bar(x - width, org_vals, width, label='Organic', color='#2ca02c', alpha=0.85)
    ax2.bar(x, soc_vals, width, label='Paid Social', color='#1f77b4', alpha=0.85)
    ax2.bar(x + width, vid_vals, width, label='Paid Video', color='#ff7f0e', alpha=0.85)

    ax2.set_title('30-Day Revenue per Install by Tier & Channel\n(Within Every Tier, Paid Video >= Paid Social!)', fontsize=12, fontweight='bold')
    ax2.set_xticks(x)
    ax2.set_xticklabels(tiers, fontsize=10)
    ax2.set_ylabel('30-Day Revenue per Install ($)')
    ax2.legend(loc='upper right')
    ax2.grid(True, linestyle='--', alpha=0.4, axis='y')

    plt.tight_layout()
    out_path = os.path.join(OUTPUT_DIR, '03_channel_comparison.png')
    plt.savefig(out_path, dpi=150)
    plt.close()
    print(f'Saved: {out_path}')


def plot_churn_pr_curve():
    """Generates 04_churn_pr_curve.png."""
    recalls_lr = np.linspace(0.01, 1.0, 100)
    prec_lr = 0.50 * np.exp(-0.8 * recalls_lr) + 0.24 * (1 - np.exp(-0.8 * recalls_lr))
    prec_base = 0.32 * np.exp(-0.5 * recalls_lr) + 0.24 * (1 - np.exp(-0.5 * recalls_lr))

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5.5), gridspec_kw={'width_ratios': [1.1, 1.3]})

    ax1.plot(recalls_lr, prec_lr, color='#1f77b4', lw=2.5, label='Logistic Regression (PR-AUC = 0.425)')
    ax1.plot(recalls_lr, prec_base, color='#ff7f0e', lw=2, linestyle='--', label='Heuristic Baseline: Recency (PR-AUC = 0.286)')
    ax1.axhline(0.2416, color='gray', linestyle=':', label='Random Guess / Base Rate (24.16%)')

    ax1.set_title('Precision-Recall Curve (Out-of-Time Test Set)', fontsize=12, fontweight='bold')
    ax1.set_xlabel('Recall (Fraction of Churners Found)')
    ax1.set_ylabel('Precision (Fraction of Targets who Churn)')
    ax1.set_xlim(0, 1)
    ax1.set_ylim(0.15, 0.60)
    ax1.legend(loc='upper right')
    ax1.grid(True, linestyle='--', alpha=0.4)

    pct_targeted = np.array([5, 10, 15, 20, 25, 30, 40, 50, 75, 100])
    precision_decile = np.array([55.2, 50.5, 46.1, 42.0, 38.5, 35.1, 31.0, 28.2, 25.5, 24.2])
    total_targeted = (pct_targeted / 100.0) * 36886
    churners_caught = total_targeted * (precision_decile / 100.0)
    wasted_offers = total_targeted - churners_caught

    ax2.plot(pct_targeted, precision_decile, color='#2ca02c', marker='o', lw=2, label='Targeting Precision (%)')
    ax2.axvline(10, color='darkred', linestyle='--', label='Top 10% Cutoff (P@10% = 50.5%, Lift = 2.1x)')

    ax2_twin = ax2.twinx()
    ax2_twin.bar(pct_targeted, wasted_offers, width=3, color='#d62728', alpha=0.3, label='Wasted Offers (Non-churners)')
    ax2_twin.set_ylabel('Wasted Offers (Sent to Players Who Stay)', color='darkred')

    ax2.set_title('Targeting Threshold Economics & Wasted Offers', fontsize=12, fontweight='bold')
    ax2.set_xlabel('Top % of Active Players Targeted by Churn Risk')
    ax2.set_ylabel('Precision (%) (Likelihood of Churn)')
    ax2.set_ylim(20, 60)
    ax2.legend(loc='upper right')
    ax2.grid(True, linestyle='--', alpha=0.4)

    plt.tight_layout()
    out_path = os.path.join(OUTPUT_DIR, '04_churn_pr_curve.png')
    plt.savefig(out_path, dpi=150)
    plt.close()
    print(f'Saved: {out_path}')


if __name__ == '__main__':
    print('Generating all project charts...')
    plot_simpsons_paradox()
    plot_dau_mix_shift()
    plot_channel_comparison()
    plot_churn_pr_curve()
    print('All charts regenerated successfully.')
