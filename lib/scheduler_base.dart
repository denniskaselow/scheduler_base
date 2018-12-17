library scheduler.base;

import 'dart:math';

import 'package:intl/intl.dart';

DateTime _today = DateTime.now();

class TimeSlot extends Object with HeightMixin {
  String name, description;
  DateTime start, end;
  TimeSlot([this.name, this.start, this.end, this.description = '']);

  Duration getDuration() => end.difference(start);
  String getStartLabel() => timeFormat.format(start);
  String getDurationLabel() => '${getDuration().inMinutes} min';
  double getProgress() {
    var timepassed = DateTime.now().difference(start);
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

  RbtvTimeSlot.decode(Map<String, dynamic> encoded) {
    name = encoded['name'];
    description = encoded['description'];
    start = DateTime.parse(encoded['start']);
    end = DateTime.parse(encoded['end']);
    height = encoded['height'];
    live = encoded['live'];
    premiere = encoded['premiere'];
  }

  Object toJson() => {
        'name': name,
        'description': description,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'height': height,
        'live': live,
        'premiere': premiere,
      };

  String toString() => toJson().toString();
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
    var today = DateTime.now();
    var days = [
      Day(today.subtract(Duration(days: 1)),
          getTimeSlots(today.subtract(Duration(days: 1)))),
      Day(today, getTimeSlots(today)),
      Day(today.add(Duration(days: 1)),
          getTimeSlots(today.add(Duration(days: 1))))
    ];
    return days;
  }

  List<TimeSlot> getTimeSlots(DateTime date) {
    var random = Random();
    var start = DateTime(date.year, date.month, date.day, random.nextInt(24),
        random.nextInt(60));
    var end = start.add(Duration(minutes: 5 + random.nextInt(180)));
    var timeSlot = TimeSlot('Testing', start, end);
    var timeSlots = [timeSlot];
    fillTimeSlots(timeSlots, date);
    return timeSlots;
  }

  void fillTimeSlots(List<TimeSlot> timeSlots, DateTime date) {
    if (timeSlots.length == 0) {
      var nextDay = date.add(Duration(days: 1));
      timeSlots.add(getEmptyTimeSlot(
          DateTime(date.year, date.month, date.day, startHour, startMinute),
          DateTime(nextDay.year, nextDay.month, nextDay.day, startHour,
              startMinute)));
      return;
    }

    var current = timeSlots.first;
    var emptySlot = getEmptyTimeSlot(
        DateTime(current.start.year, current.start.month, current.start.day,
            startHour, startMinute),
        DateTime(current.start.year, current.start.month, current.start.day,
            current.start.hour, current.start.minute));
    if (emptySlot.getDuration().inMinutes > 0) {
      timeSlots.insert(0, emptySlot);
    }

    current = timeSlots.last;
    var tommorow = date.add(Duration(days: 1));
    emptySlot = getEmptyTimeSlot(
        DateTime(current.end.year, current.end.month, current.end.day,
            current.end.hour, current.end.minute),
        DateTime(tommorow.year, tommorow.month, tommorow.day, startHour,
            startMinute));
    if (emptySlot.getDuration().inMinutes > 0) {
      timeSlots.add(emptySlot);
    }
  }

  TimeSlot getEmptyTimeSlot(DateTime start, DateTime end) {
    return EmptyTimeSlot(start, end);
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
          // sometimes the data makes no sense (2 shows starting at the same
          // time, which will result in one show being 0 minutes)
          share = share.isNaN ? 1.0 : share;
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
      baseDate = baseDate.add(Duration(days: 1));
    }
    return DateTime(baseDate.year, baseDate.month, baseDate.day,
        timeSlot.end.hour, timeSlot.end.minute);
  }

  DateTime _getStartTimeHM(hour, minute) {
    var baseDate = _today;
    if (hour >= 0 && hour < startHour ||
        hour == startHour && minute < startMinute) {
      baseDate = baseDate.add(Duration(days: 1));
    }
    return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
  }

  DateTime _getStartTime(TimeSlot timeSlot) {
    var baseDate = _today;
    if (timeSlot.start.hour >= 0 && timeSlot.start.hour < startHour ||
        timeSlot.start.hour == startHour &&
            timeSlot.start.minute < startMinute) {
      baseDate = baseDate.add(Duration(days: 1));
    }
    return DateTime(baseDate.year, baseDate.month, baseDate.day,
        timeSlot.start.hour, timeSlot.start.minute);
  }
}

class HeightMixin {
  int height;
}

final DateFormat dateFormat = DateFormat.yMEd();
final DateFormat timeFormat = DateFormat.Hm();
final DateFormat dayNameFormat = DateFormat.E("en_US");
final DateFormat dateIdFormat = DateFormat('yyyyMMdd');
final DateFormat timeIdFormat = DateFormat('HHmm');
