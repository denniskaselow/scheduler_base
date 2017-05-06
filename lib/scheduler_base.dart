library scheduler.base;

import 'dart:math';

import 'package:intl/intl.dart';
import 'package:dson/dson.dart';

DateTime _today = new DateTime.now();

@serializable
class TimeSlot extends Object with HeightMixin {
  String name, description;
  DateTime start, end;
  TimeSlot([this.name, this.start, this.end, this.description = '']);

  Duration getDuration() => end.difference(start);
  String getStartLabel() => timeFormat.format(start);
  String getDurationLabel() => '${getDuration().inMinutes} min';
  double getProgress() {
    var timepassed = new DateTime.now().difference(start);
    if (timepassed.inMilliseconds < 0) {
      return 0.0;
    }
    var duration = getDuration();
    if (timepassed.inMilliseconds > duration.inMilliseconds) {
      return 100.0;
    }
    return 100.0 * timepassed.inMilliseconds / duration.inMilliseconds;
  }
}

@serializable
class RbtvTimeSlot extends TimeSlot {
  bool live;
  bool premiere;
  RbtvTimeSlot(
      [String name,
      DateTime start,
      DateTime end,
      String description = '',
      this.live,
      this.premiere])
      : super(name, start, end, description);
}

class EmptyTimeSlot extends TimeSlot {
  EmptyTimeSlot(DateTime start, DateTime end) : super('', start, end);
}

class EmptyRbtvTimeSlot extends RbtvTimeSlot {
  EmptyRbtvTimeSlot(DateTime start, DateTime end)
      : super('', start, end, '', false, false);
}

class Day extends Object with HeightMixin {
  DateTime date;
  List<TimeSlot> timeSlots;
  Day(this.date, [this.timeSlots = const []]);
  String get label => dateFormat.format(date);
  String get dayName => dayNameFormat.format(date);

  bool get isToday =>
      _today.year == date.year &&
      _today.month == date.month &&
      _today.day == date.day;
}

class SchedulerService {
  int startHour = 0;
  int startMinute = 0;

  List<Day> getDays() {
    var today = new DateTime.now();
    var days = [
      new Day(today.subtract(new Duration(days: 1)),
          getTimeSlots(today.subtract(new Duration(days: 1)))),
      new Day(today, getTimeSlots(today)),
      new Day(today.add(new Duration(days: 1)),
          getTimeSlots(today.add(new Duration(days: 1))))
    ];
    return days;
  }

  List<TimeSlot> getTimeSlots(DateTime date) {
    var random = new Random();
    var start = new DateTime(date.year, date.month, date.day,
        random.nextInt(24), random.nextInt(60));
    var end = start.add(new Duration(minutes: 5 + random.nextInt(180)));
    var timeSlot = new TimeSlot('Testing', start, end);
    var timeSlots = [timeSlot];
    fillTimeSlots(timeSlots, date);
    return timeSlots;
  }

  void fillTimeSlots(List<TimeSlot> timeSlots, DateTime date) {
    if (timeSlots.length == 0) {
      var nextDay = date.add(new Duration(days: 1));
      timeSlots.add(getEmptyTimeSlot(
          new DateTime(date.year, date.month, date.day, startHour, startMinute),
          new DateTime(nextDay.year, nextDay.month, nextDay.day, startHour,
              startMinute)));
      return;
    }

    var current = timeSlots.first;
    var emptySlot = getEmptyTimeSlot(
        new DateTime(current.start.year, current.start.month, current.start.day,
            startHour, startMinute),
        new DateTime(current.start.year, current.start.month, current.start.day,
            current.start.hour, current.start.minute));
    if (emptySlot.getDuration().inMinutes > 0) {
      timeSlots.insert(0, emptySlot);
    }

    current = timeSlots.last;
    var tommorow = date.add(new Duration(days: 1));
    emptySlot = getEmptyTimeSlot(
        new DateTime(current.end.year, current.end.month, current.end.day,
            current.end.hour, current.end.minute),
        new DateTime(tommorow.year, tommorow.month, tommorow.day, startHour,
            startMinute));
    if (emptySlot.getDuration().inMinutes > 0) {
      timeSlots.add(emptySlot);
    }
  }

  TimeSlot getEmptyTimeSlot(DateTime start, DateTime end) {
    return new EmptyTimeSlot(start, end);
  }

  void optimizeHeights(List<Day> days, int minHeight) {
    var shortSlots = <TimeSlot>[];
    for (var day in days) {
      for (var timeSlot in day.timeSlots) {
        timeSlot.height = timeSlot.getDuration().inMinutes;
        if (timeSlot.height < minHeight) {
          shortSlots.add(timeSlot);
        }
      }
    }
    compressTimeSlots(days, minHeight);
    increaseToMinHeight(shortSlots, minHeight, days);
  }

  void increaseToMinHeight(
      List<TimeSlot> shortSlots, int minHeight, List<Day> days) {
    for (var shortSlot in shortSlots) {
      if (shortSlot.height >= minHeight) continue;
      var startTime =
          _getStartTimeHM(shortSlot.start.hour, shortSlot.start.minute);
      var endTime = _getEndTime(shortSlot);
      var missingHeight = minHeight - shortSlot.height;
      for (var day in days) {
        for (var timeSlot in day.timeSlots) {
          if (shortSlot == timeSlot) break;
          var otherStartTime = _getStartTime(timeSlot);
          if (otherStartTime.isAfter(endTime)) break;
          var otherEndTime = _getEndTime(timeSlot);
          if (otherEndTime.isBefore(startTime)) continue;
          var jointStartTime =
              otherStartTime.isBefore(startTime) ? startTime : otherStartTime;
          var jointEndTime =
              otherEndTime.isAfter(endTime) ? endTime : otherEndTime;
          var jointDuration = jointEndTime.difference(jointStartTime);
          var share =
              jointDuration.inMinutes / shortSlot.getDuration().inMinutes;
          timeSlot.height += (missingHeight * share).round();
        }
      }
      shortSlot.height = minHeight;
    }
  }

  void compressTimeSlots(List<Day> days, int minHeight) {
    var startTime = _getStartTimeHM(startHour, startMinute);
    var shortestSlot;
    var diffOfShortestSlot;
    var slots = [];
    do {
      for (var day in days) {
        for (var timeSlot in day.timeSlots) {
          var diff = _getEndTime(timeSlot).difference(startTime);
          if (diff.inMinutes <= 0) continue;
          if (null == shortestSlot || diff < diffOfShortestSlot) {
            shortestSlot = timeSlot;
            diffOfShortestSlot = diff;
          }
          slots.add(timeSlot);
          break;
        }
      }
      var endTime = _getEndTime(shortestSlot);
      var duration = endTime.difference(startTime);
      if (duration.inMinutes > minHeight) {
        slots.forEach((slot) {
          slot.height -= duration.inMinutes - minHeight;
        });
      }
      startTime = endTime;
      shortestSlot = null;
      slots = [];
    } while (!(startTime.hour == startHour && startTime.minute == startMinute));
  }

  DateTime _getEndTime(TimeSlot timeSlot) {
    var baseDate = _today;
    if (timeSlot.end.hour >= 0 && timeSlot.end.hour < startHour ||
        timeSlot.end.hour == startHour && timeSlot.end.minute <= startMinute) {
      baseDate = baseDate.add(new Duration(days: 1));
    }
    return new DateTime(baseDate.year, baseDate.month, baseDate.day,
        timeSlot.end.hour, timeSlot.end.minute);
  }

  DateTime _getStartTimeHM(hour, minute) {
    var baseDate = _today;
    if (hour >= 0 && hour < startHour ||
        hour == startHour && minute < startMinute) {
      baseDate = baseDate.add(new Duration(days: 1));
    }
    return new DateTime(
        baseDate.year, baseDate.month, baseDate.day, hour, minute);
  }

  DateTime _getStartTime(TimeSlot timeSlot) {
    var baseDate = _today;
    if (timeSlot.start.hour >= 0 && timeSlot.start.hour < startHour ||
        timeSlot.start.hour == startHour &&
            timeSlot.start.minute < startMinute) {
      baseDate = baseDate.add(new Duration(days: 1));
    }
    return new DateTime(baseDate.year, baseDate.month, baseDate.day,
        timeSlot.start.hour, timeSlot.start.minute);
  }
}

class HeightMixin {
  int height;
}

final DateFormat dateFormat = new DateFormat.yMEd();
final DateFormat timeFormat = new DateFormat.Hm();
final DateFormat dayNameFormat = new DateFormat.E("en_US");
final DateFormat dateIdFormat = new DateFormat('yyyyMMdd');
final DateFormat timeIdFormat = new DateFormat('HHmm');
