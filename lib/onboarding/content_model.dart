class UnbordingContent {
  final String image;
  final String title;
  final String discription;

  UnbordingContent({
    required this.image,
    required this.title,
    required this.discription,
  });
}

List<UnbordingContent> contents = [
  UnbordingContent(
    image: 'assets/onboarding-1.png',
    title: 'Welcome to Silver Support',
    discription:
        'Connecting students with seniors for meaningful community support.',
  ),
  UnbordingContent(
    image: 'assets/onboarding-2.png',
    title: 'Everyday Support',
    discription:
        'Receive assistance with errands, chores, and more through students',
  ),
  UnbordingContent(
    image: 'assets/onboarding-3.png',
    title: 'Volunteer Opportunities',
    discription:
        'Students can find local volunteering opportunities to help seniors in need, and in turn be awarded volunteer hours.',
  ),
];
