library scheduler.test;

import 'package:scheduler_base/scheduler_base.dart';
import 'package:test/test.dart';

void main() {
  group('TimeSlot', () {
    TimeSlot timeSlot;

    setUp(() {
      timeSlot = new TimeSlot('testing', new DateTime.utc(2016, 1, 3, 13, 37),
          new DateTime.utc(2016, 1, 3, 14, 00));
    });

    test('returns corret duration', () {
      expect(timeSlot.getDuration(), equals(new Duration(minutes: 23)));
    });
  });
  group('SchedulerService', () {
    SchedulerService service;

    setUp(() {
      service = new SchedulerService();
    });

    test('returns last, current and next day', () {
      var days = service.getDays();
      var today = new DateTime.now();
      var yesterday = today.subtract(new Duration(days: 1));
      var tomorrow = today.add(new Duration(days: 1));

      expect(days.length, equals(3));
      expect(days[0].date.year, equals(yesterday.year));
      expect(days[0].date.month, equals(yesterday.month));
      expect(days[0].date.day, equals(yesterday.day));

      expect(days[1].date.year, equals(today.year));
      expect(days[1].date.month, equals(today.month));
      expect(days[1].date.day, equals(today.day));

      expect(days[2].date.year, equals(tomorrow.year));
      expect(days[2].date.month, equals(tomorrow.month));
      expect(days[2].date.day, equals(tomorrow.day));
    });

    test('fills missing TimeSlots in Day', () {
      var timeSlots = service.getTimeSlots(new DateTime(2016, 01, 24));

      expect(timeSlots.first.start, equals(new DateTime(2016, 01, 24)));
      expect(timeSlots.last.end, equals(new DateTime(2016, 01, 25)));

      for (int i = 1; i < timeSlots.length; i++) {
        expect((timeSlots[i - 1].end), equals(timeSlots[i].start));
      }
    });

    test('reduces height of big TimeSlots in Day', () {
      var day1 = new Day(new DateTime(2016, 01, 25), [
        new TimeSlot(
            '', new DateTime(2016, 01, 24), new DateTime(2016, 01, 24, 10)),
        new TimeSlot(
            '', new DateTime(2016, 01, 24, 10), new DateTime(2016, 01, 25))
      ]);
      var day2 = new Day(new DateTime(2016, 01, 25), [
        new TimeSlot(
            '', new DateTime(2016, 01, 25), new DateTime(2016, 01, 25, 14)),
        new TimeSlot(
            '', new DateTime(2016, 01, 25, 14), new DateTime(2016, 01, 26))
      ]);

      service.optimizeHeights([day1, day2], 100);

      expect(day1.timeSlots[0].height, equals(100));
      expect(day1.timeSlots[1].height, equals(200));
      expect(day2.timeSlots[0].height, equals(200));
      expect(day2.timeSlots[1].height, equals(100));
    });

    test('increases height of short TimeSlots in Day', () {
      var day1 = new Day(new DateTime(2016, 01, 24), [
        new TimeSlot(
            '', new DateTime(2016, 01, 24), new DateTime(2016, 01, 24, 1)),
        new TimeSlot(
            '', new DateTime(2016, 01, 24, 1), new DateTime(2016, 01, 25))
      ]);
      var day2 = new Day(new DateTime(2016, 01, 25), [
        new TimeSlot(
            '', new DateTime(2016, 01, 25), new DateTime(2016, 01, 25, 23)),
        new TimeSlot(
            '', new DateTime(2016, 01, 25, 23), new DateTime(2016, 01, 26))
      ]);

      service.optimizeHeights([day1, day2], 100);

      expect(day1.timeSlots[0].height, equals(100));
      expect(day1.timeSlots[1].height, equals(200));
      expect(day2.timeSlots[0].height, equals(200));
      expect(day2.timeSlots[1].height, equals(100));
    });

    test('increases height of short TimeSlots in Day only once', () {
      var day1 = new Day(new DateTime(2016, 01, 24), [
        new TimeSlot(
            '', new DateTime(2016, 01, 24), new DateTime(2016, 01, 24, 1)),
        new TimeSlot(
            '', new DateTime(2016, 01, 24, 1), new DateTime(2016, 01, 25))
      ]);
      var day2 = new Day(new DateTime(2016, 01, 25), [
        new TimeSlot(
            '', new DateTime(2016, 01, 25), new DateTime(2016, 01, 25, 1)),
        new TimeSlot(
            '', new DateTime(2016, 01, 25, 1), new DateTime(2016, 01, 26))
      ]);
      var day3 = new Day(new DateTime(2016, 01, 26), [
        new TimeSlot(
            '', new DateTime(2016, 01, 26), new DateTime(2016, 01, 26, 1)),
        new TimeSlot(
            '', new DateTime(2016, 01, 26, 1), new DateTime(2016, 01, 27))
      ]);

      service.optimizeHeights([day1, day2, day3], 100);

      expect(day1.timeSlots[0].height, equals(100));
      expect(day1.timeSlots[1].height, equals(100));
      expect(day2.timeSlots[0].height, equals(100));
      expect(day2.timeSlots[1].height, equals(100));
      expect(day3.timeSlots[0].height, equals(100));
      expect(day3.timeSlots[1].height, equals(100));
    });
  });
}
