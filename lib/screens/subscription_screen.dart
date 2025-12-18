import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _mySub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      // 1️⃣ Load all subscription plans
      final planRes = await supabase.from('subscription_plans').select();
      _plans = (planRes as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // 2️⃣ Load user's latest subscription
      final subRes = await supabase
          .from('user_subscriptions')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1);

      if (subRes.isNotEmpty) {
        _mySub = Map<String, dynamic>.from(subRes.first);
      } else {
        _mySub = null;
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

   Future<void> _cancelSubscription() async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null || _mySub == null) return;

  // 1️⃣ Confirm dialog
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cancel Subscription'),
      content: const Text(
        'Are you sure you want to cancel your subscription?\n\n'
        'You will continue to have access until the expiry date.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('No'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Yes, Cancel',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  // 2️⃣ Update database
  setState(() => _loading = true);

  try {
    await supabase
        .from('user_subscriptions')
        .update({
          'status': 'cancelled',
          'cancelled_at': DateTime.now().toIso8601String(),
        })
        .eq('id', _mySub!['id']);

    // 3️⃣ Success feedback
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Subscription cancelled successfully'),
        backgroundColor: Colors.green,
      ),
    );

    // 4️⃣ Reload subscription data
    await _load();
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to cancel subscription: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}


  Future<void> _subscribe(Map<String, dynamic> plan) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      final expiresAt = DateTime.now().add(const Duration(days: 30));

      final insertRes = await supabase.from('user_subscriptions').insert({
        'user_id': user.id,
        'plan_id': plan['id'],
        'status': 'active',
        'expires_at': expiresAt.toIso8601String(),
        'metadata': {'source': 'manual_test'}
      }).select();

      if (insertRes.isNotEmpty) {
        _mySub = Map<String, dynamic>.from(insertRes.first);
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Subscribed!')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Subscribe failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _planCard(Map<String, dynamic> plan) {
  final isCurrent = _mySub?['plan_id'] == plan['id'];
  final isPopular = plan['is_popular'] == true;

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(color: Colors.black12, blurRadius: 8),
      ],
      border: isCurrent
          ? Border.all(color: AppColors.primaryBlue, width: 2)
          : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🟦 Title + Popular badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              plan['name'],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isPopular)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Popular',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 6),

        // 💰 Price
        Text(
          "RM ${plan['price']} / ${plan['billing_interval']}",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade700,
          ),
        ),

        const SizedBox(height: 12),

        // ✅ Feature list
        if (plan['features'] is List)
          ...((plan['features'] as List).map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f.toString(),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          )),

        const SizedBox(height: 14),

        // 🔘 Action button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isCurrent ? null : () => _subscribe(plan),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrent
                  ? Colors.grey.shade300
                  : AppColors.primaryBlue,
              foregroundColor:
                  isCurrent ? Colors.black54 : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(isCurrent ? 'Current Plan' : 'Select Plan'),
          ),
        ),
      ],
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    final isActive = _mySub?['status'] == 'active';
      return Scaffold(
      appBar: AppBar(
        title: const Text("Subscription Plans"),
        backgroundColor: AppColors.primaryBlue,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                 
                  if (_mySub != null) ...[
  Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(color: Colors.black12, blurRadius: 6),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Current Subscription',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text('Status: ${_mySub!['status']}'),
        Text('Expires on: ${_mySub!['expires_at']}'),

        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
  onPressed: isActive ? _cancelSubscription : null,
  style: OutlinedButton.styleFrom(
    foregroundColor: isActive ? Colors.red : Colors.grey,
    side: BorderSide(color: isActive ? Colors.red : Colors.grey),
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  child: Text(
    isActive ? 'Cancel Subscription' : 'Subscription Cancelled',
  ),
),

        ),
      ],
    ),
  ),
  const SizedBox(height: 20),
],

                  Expanded(
                    child: ListView(
                      children: _plans.map(_planCard).toList(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  

}
