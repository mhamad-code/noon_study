const String githubUser = 'mhamad-code';
const String githubRepo = 'noon_study';
const String updateUrl =
    'https://raw.githubusercontent.com/$githubUser/$githubRepo/main/update.json';

const List<String> updateUrls = [
  'https://api.github.com/repos/$githubUser/$githubRepo/contents/update.json?ref=main',
  updateUrl,
  'https://cdn.jsdelivr.net/gh/$githubUser/$githubRepo@main/update.json',
];
