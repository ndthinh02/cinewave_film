class AppConfig {
  static const movieBaseUrl = String.fromEnvironment(
    'MOVIE_BASE_URL',
    defaultValue: 'https://phimapi.com',
  );

  static const backendBaseUrl = String.fromEnvironment('BACKEND_BASE_URL',
      defaultValue: 'https://cinewave-film-backend.onrender.com/api'
      // defaultValue: 'http://10.0.2.2:8080/api',
      );
}
