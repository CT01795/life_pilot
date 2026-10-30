import unittest
from datetime import datetime, timezone
from unittest.mock import MagicMock, patch
from external import repository_weather


class WeatherRepositoryCostTest(unittest.TestCase):
    def test_backend_daily_cleanup_clears_weather_once_before_recording_marker(self):
        from event.service_event import _cleanup_recommended_events_once_per_day
        connection = MagicMock()
        results = [MagicMock() for _ in range(8)]
        results[1].scalar.return_value = False
        for i in [3, 4, 5]:
            results[i].scalar.return_value = 0
        connection.execute.side_effect = results
        with patch('event.service_event.SessionLocal', return_value=connection):
            self.assertTrue(_cleanup_recommended_events_once_per_day())
        statements = [str(call.args[0]) for call in connection.execute.call_args_list]
        self.assertIn('delete from public.weather_forecast_cache', statements[6])
        self.assertIn('recommended_event_url', statements[7])
        connection.commit.assert_called_once()

    def test_already_cleaned_day_does_not_repeat_weather_delete(self):
        from event.service_event import _cleanup_recommended_events_once_per_day
        connection = MagicMock()
        connection.execute.return_value.scalar.return_value = True
        with patch('event.service_event.SessionLocal', return_value=connection):
            self.assertFalse(_cleanup_recommended_events_once_per_day())
        self.assertEqual(connection.execute.call_count, 2)

    def test_upsert_does_not_scan_and_delete_all_expired_rows(self):
        engine = MagicMock()
        connection = engine.begin.return_value.__enter__.return_value
        with patch.object(repository_weather, 'get_database_engine', return_value=engine):
            repository_weather.save_weather_forecast_cache(
                cache_key='one', forecast=[], expires_at=datetime.now(timezone.utc))
        connection.execute.assert_called_once()
        self.assertIn('insert into public.weather_forecast_cache', str(connection.execute.call_args.args[0]))
        self.assertNotIn('delete from', str(connection.execute.call_args.args[0]))

    def test_cleanup_only_deletes_expired_cache_and_reuses_daily_transaction(self):
        connection = MagicMock()
        repository_weather.cleanup_expired_weather_cache(connection)
        connection.execute.assert_called_once()
        statement = str(connection.execute.call_args.args[0])
        self.assertIn('where expires_at <= now()', statement)
        connection.commit.assert_not_called()
