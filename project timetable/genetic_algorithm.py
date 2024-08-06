import random
import copy

# Define days and time slots for theory
DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
TIME_SLOTS = ["9:30-11:30", "11:30-1:30", "2:00-4:00", "4:00-6:00"]

# Define a global state to track teacher availability across all courses
teacher_availability = {day: {slot: None for slot in TIME_SLOTS} for day in DAYS}

def initialize_population(population_size, subjects):
    population = []
    for _ in range(population_size):
        timetable = generate_individual_timetable(subjects)
        population.append(timetable)
    return population

def generate_individual_timetable(subjects):
    timetable = {}
    occupied_slots = {day: {slot: None for slot in TIME_SLOTS} for day in DAYS}
    available_slots = {day: TIME_SLOTS.copy() for day in DAYS}
    lab_combinations = [("9:30-11:30", "11:30-1:30"), ("2:00-4:00", "4:00-6:00")]

    for subject in subjects:
        if 'lab' in subject['subject_type']:
            allocate_periods(4, subject, occupied_slots, available_slots, timetable, 'lab', lab_combinations)
            allocate_periods(2, subject, occupied_slots, available_slots, timetable, 'theory')
        elif 'theory' in subject['subject_type']:
            allocate_periods(2, subject, occupied_slots, available_slots, timetable, 'theory')

    return timetable

def allocate_periods(periods_needed, subject, occupied_slots, available_slots, timetable, period_type, lab_combinations=None):
    allocated_periods = 0
    days = DAYS.copy()
    random.shuffle(days)  # Shuffle days to ensure more even distribution

    for day in days:
        if allocated_periods >= periods_needed:
            break
        if period_type == 'lab' and lab_combinations:
            random.shuffle(lab_combinations)  # Shuffle lab combinations to ensure variety
            for slot_pair in lab_combinations:
                if all(slot in available_slots[day] for slot in slot_pair) and \
                   all(teacher_availability[day][slot] != subject['teacher_id'] for slot in slot_pair):
                    timetable[(day, slot_pair[0])] = {
                        'subject_name': subject['subject_name'],
                        'teacher_id': subject['teacher_id'],
                        'type': 'lab',
                        'colspan': 2
                    }
                    timetable[(day, slot_pair[1])] = {
                        'subject_name': subject['subject_name'],
                        'teacher_id': subject['teacher_id'],
                        'type': 'lab',
                        'colspan': 0
                    }
                    for slot in slot_pair:
                        occupied_slots[day][slot] = subject['teacher_id']
                        teacher_availability[day][slot] = subject['teacher_id']
                        available_slots[day].remove(slot)
                    allocated_periods += 2  # Increment by 2 because we allocated two slots
                    break
        else:
            possible_slots = [slot for slot in available_slots[day] if occupied_slots[day][slot] is None and 
                              teacher_availability[day][slot] != subject['teacher_id']]
            if possible_slots:
                time_slot = random.choice(possible_slots)
                timetable[(day, time_slot)] = {
                    'subject_name': subject['subject_name'],
                    'teacher_id': subject['teacher_id'],
                    'type': period_type
                }
                occupied_slots[day][time_slot] = subject['teacher_id']
                teacher_availability[day][time_slot] = subject['teacher_id']
                available_slots[day].remove(time_slot)
                allocated_periods += 1

def calculate_fitness(timetable):
    clashes = 0
    for (day, time_slot), details in timetable.items():
        if teacher_availability[day][time_slot] and \
           teacher_availability[day][time_slot] != details['teacher_id']:
            clashes += 1
    return -clashes * 10

def selection(population, fitnesses, num_parents):
    parents = random.choices(population, weights=[max(0, f) for f in fitnesses], k=num_parents)
    return parents

def crossover(parent1, parent2):
    child = copy.deepcopy(parent1)
    crossover_point = random.randint(0, len(parent1))
    for i, key in enumerate(parent2):
        if i > crossover_point:
            child[key] = parent2[key]
    return child

def mutate(timetable, mutation_rate):
    for key in timetable:
        if random.random() < mutation_rate:
            day = random.choice(DAYS)
            time_slot = random.choice(TIME_SLOTS)
            timetable[key] = timetable.get(key, {'subject_name': 'N/A', 'teacher_id': 'N/A'})
            timetable[key] = timetable[key]
    return timetable

def genetic_algorithm(courses, population_size, num_generations, num_parents, mutation_rate):
    global teacher_availability
    best_timetables = {}
    for course in courses:
        teacher_availability = {day: {slot: None for slot in TIME_SLOTS} for day in DAYS}
        population = initialize_population(population_size, course['subjects'])
        for generation in range(num_generations):
            fitnesses = [calculate_fitness(individual) for individual in population]
            if all(f <= 0 for f in fitnesses):
                fitnesses[0] = 1

            new_population = []
            for _ in range(population_size):
                parents = selection(population, fitnesses, num_parents)
                child = crossover(parents[0], parents[1])
                child = mutate(child, mutation_rate)
                new_population.append(child)
            population = new_population

        best_timetable = max(population, key=calculate_fitness)
        best_timetables[course['course_id']] = best_timetable
    return best_timetables



