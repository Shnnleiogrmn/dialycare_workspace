import '../models/patient.dart';

const patients = <Patient>[
  Patient(id: 'DC-001', name: 'Maria Santos', age: 58, gender: 'Female', contact: '123-456-789-0', room: 'Room 01', batch: 'Batch A', time: '8:00 AM', status: 'In Progress'),
  Patient(id: 'DC-002', name: 'Jose Reyes', age: 63, gender: 'Male', contact: '123-456-789-1', room: 'Room 02', batch: 'Batch A', time: '8:15 AM', status: 'Completed'),
  Patient(id: 'DC-003', name: 'Ana Cruz', age: 47, gender: 'Female', contact: '123-456-789-2', room: 'Room 03', batch: 'Batch B', time: '9:00 AM', status: 'Ready for Pick Up'),
  Patient(id: 'DC-004', name: 'Ramon Diaz', age: 70, gender: 'Male', contact: '123-456-789-3', room: 'Room 04', batch: 'Batch B', time: '9:15 AM', status: 'In Progress'),
  Patient(id: 'DC-005', name: 'Liza Garcia', age: 52, gender: 'Female', contact: '123-456-789-4', room: 'Room 05', batch: 'Batch C', time: '10:00 AM', status: 'Completed'),
  Patient(id: 'DC-006', name: 'David Lim', age: 61, gender: 'Male', contact: '123-456-789-5', room: 'Room 06', batch: 'Batch C', time: '10:30 AM', status: 'Ready for Pick Up'),
];

const notificationItems = <Map<String, String>>[
  {'type': 'Patients', 'title': 'Session Started', 'message': 'Maria Santos dialysis session has started.', 'time': '08:00 AM', 'icon': 'start'},
  {'type': 'System', 'title': 'System Update', 'message': 'DialyCare has been updated successfully.', 'time': '08:00 AM', 'icon': 'system'},
  {'type': 'Patients', 'title': 'Session Ending Soon', 'message': 'Ramon Diaz session will end in 10 minutes.', 'time': '08:00 AM', 'icon': 'ending'},
  {'type': 'Patients', 'title': 'Pickup Notification', 'message': 'Ana Cruz is ready for pickup.', 'time': '08:00 AM', 'icon': 'pickup'},
  {'type': 'System', 'title': 'Schedule Reminder', 'message': 'Jose Reyes session is scheduled at 8:00 AM.', 'time': '08:00 AM', 'icon': 'reminder'},
  {'type': 'Relatives', 'title': 'Relatives Notification', 'message': 'A designated relative has been notified.', 'time': '08:00 AM', 'icon': 'relative'},
];
