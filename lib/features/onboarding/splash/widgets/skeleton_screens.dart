import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerSkeleton extends StatelessWidget {
  final Widget child;

  const ShimmerSkeleton({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: child,
    );
  }
}

class DriverHomeSkeleton extends StatelessWidget {
  const DriverHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const Icon(Icons.menu, color: Colors.grey),
        title: Container(
          width: 80,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.grey,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Icon(Icons.notifications_outlined, color: Colors.grey),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    width: 70,
                    height: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Container(
                    width: 70,
                    height: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ShimmerSkeleton(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Online Banner
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Stats cards row
                    Row(
                      children: List.generate(3, (index) {
                        return Expanded(
                          child: Container(
                            margin: EdgeInsets.only(
                                right: index == 2 ? 0 : 10),
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    // Section title
                    Container(
                      width: 120,
                      height: 20,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    // Nearby load cards
                    ...List.generate(2, (index) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        width: double.infinity,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            // Bottom Action buttons
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFEEEEEE)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(28),
                      ),
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
}

class LoadOwnerHomeSkeleton extends StatelessWidget {
  const LoadOwnerHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // AppBar Header
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.menu, color: Colors.grey),
                  ),
                  Container(
                    width: 80,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Spacer(),
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.notifications_outlined, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          // Shimmering Mock Map Area
          Expanded(
            child: ShimmerSkeleton(
              child: Stack(
                children: [
                  // Draw some block shapes to look like a map layout
                  Positioned.fill(
                    child: Container(
                      color: Colors.grey[200],
                      padding: const EdgeInsets.all(16),
                      child: GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        physics: const NeverScrollableScrollPhysics(),
                        children: List.generate(4, (index) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[350],
                              borderRadius: BorderRadius.circular(12),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  // Filter Chips
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Row(
                      children: [
                        Container(
                          width: 90,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 90,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom panel
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
                ],
              ),
              child: ShimmerSkeleton(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 140,
                          height: 18,
                          color: Colors.grey,
                        ),
                        Container(
                          width: 60,
                          height: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
