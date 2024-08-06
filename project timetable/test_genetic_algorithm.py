from genetic_algorithm import genetic_algorithm, TIME_SLOTS, DAYS

# Simulate course and subject data
courses = [
    {
        'course_id': 'CSE101',
        'course_name': 'Introduction to Computer Science',
        'department': 'CSE',
        'semester': 1,
        'subjects': [
            {'subject_name': 'Programming Basics', 'subject_type': 'theory'},
            {'subject_name': 'Data Structures', 'subject_type': 'theory'},
            {'subject_name': 'Algorithms', 'subject_type': 'theory'},
            {'subject_name': 'Computer Lab', 'subject_type': 'lab'}
        ]
    },
    {
        'course_id': 'ECE101',
        'course_name': 'Introduction to Electronics',
        'department': 'ECE',
        'semester': 1,
        'subjects': [
            {'subject_name': 'Circuit Theory', 'subject_type': 'theory'},
            {'subject_name': 'Digital Electronics', 'subject_type': 'theory'},
            {'subject_name': 'Microprocessors', 'subject_type': 'theory'},
            {'subject_name': 'Electronics Lab', 'subject_type': 'lab'}
        ]
    }
]

# Define parameters for the genetic algorithm
population_size = 10
num_generations = 5
num_parents = 2
mutation_rate = 0.1

# Run the genetic algorithm
best_timetables = genetic_algorithm(courses, population_size, num_generations, num_parents, mutation_rate)

# Print the resulting best timetables
for course_id, timetable in best_timetables.items():
    print(f"Best timetable for course {course_id}:")
    for (day, time_slot), subject in timetable.items():
        print(f"{day} {time_slot}: {subject}")
    print("\n")
