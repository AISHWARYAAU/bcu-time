    background: linear-gradient(to bottom, rgb(139, 139, 232), white);
    background-color: #333333;


CREATE TABLE course_subjects (
    course_id VARCHAR(255) NOT NULL,
    subject_id VARCHAR(255) NOT NULL,
    subject_name VARCHAR(255) NOT NULL,
    teacher_id VARCHAR(255) NOT NULL,
    teacher_name VARCHAR(255) NOT NULL,
    subject_type VARCHAR(255) NOT NULL,
    working_hours INT NOT NULL,
    FOREIGN KEY (subject_id) REFERENCES subjects(subjectid),
    FOREIGN KEY (teacher_id) REFERENCES teachers(id),
    FOREIGN KEY (course_id) REFERENCES courses(course_id)
) ENGINE=InnoDB;


@import url('https://fonts.googleapis.com/css2?family=Arial&display=swap');
    font-family: 'Indie Flower', cursive;


 CREATE TABLE `teachers` (
  `id` varchar(255) NOT NULL DEFAULT '',
  `name` varchar(255) NOT NULL,
  `working_hours` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 



 CREATE TABLE `semesters` (
  `id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1


CREATE TABLE `subjects` (
  `subjectid` varchar(255) NOT NULL,
  `subject_name` varchar(255) NOT NULL,
  `subject_type` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`subjectid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1


--------------------+
| courses | CREATE TABLE `courses` (
  `department` varchar(255) DEFAULT NULL,
  `course_name` varchar(255) DEFAULT NULL,
  `semester` varchar(255) DEFAULT NULL,
  `course_id` varchar(255) NOT NULL,
  PRIMARY KEY (`course_id`),
  KEY `department` (`department`),
  KEY `semester` (`semester`),
  CONSTRAINT `courses_ibfk_1` FOREIGN KEY (`department`) REFERENCES `departments` (`name`),
  CONSTRAINT `courses_ibfk_2` FOREIGN KEY (`semester`) REFERENCES `semesters` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1



CREATE TABLE `departments` (
  `id` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 



 CREATE TABLE `course_subjects` (
  `course_id` varchar(255) NOT NULL,
  `subject_id` varchar(255) NOT NULL,
  `subject_name` varchar(255) NOT NULL,
  `teacher_id` varchar(255) NOT NULL,
  `teacher_name` varchar(255) NOT NULL,
  `subject_type` varchar(255) NOT NULL,
  `working_hours` int(11) NOT NULL,
  KEY `subject_id` (`subject_id`),
  KEY `teacher_id` (`teacher_id`),
  KEY `course_id` (`course_id`),
  CONSTRAINT `course_subjects_ibfk_1` FOREIGN KEY (`subject_id`) REFERENCES `subjects` (`subjectid`),
  CONSTRAINT `course_subjects_ibfk_2` FOREIGN KEY (`teacher_id`) REFERENCES `teachers` (`id`),
  CONSTRAINT `course_subjects_ibfk_3` FOREIGN KEY (`course_id`) REFERENCES `courses` (`course_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1





CREATE TABLE `admins` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `password` varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=102 DEFAULT CHARSET=latin1 




2 theory period (2 hours each ) and 2 lab periods (4 hours each) for subject type theory, lab 

2 theory period (2 hours each ) for subject type theory only 



-- this code gives you the required number of periods for each subject across all courses timetable generation 
--teacher clashes are not strictly followed 

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
    lab_combinations = [("9:30-11:30", "11:30-1:30"), ("2:00-4:00", "4:00-6:00")]

    for subject in subjects:
        if 'lab' in subject['subject_type']:
            allocate_periods(2, subject, occupied_slots, timetable, 'lab', lab_combinations)
        allocate_periods(2, subject, occupied_slots, timetable, 'theory')

    # Ensure all theory-only subjects get their required periods
    for subject in subjects:
        if 'lab' not in subject['subject_type']:
            allocate_periods(2, subject, occupied_slots, timetable, 'theory')

    return timetable

def allocate_periods(periods_needed, subject, occupied_slots, timetable, period_type, lab_combinations=None):
    allocated_periods = 0
    while allocated_periods < periods_needed:
        for day in DAYS:
            if period_type == 'lab' and lab_combinations:
                for slot_pair in lab_combinations:
                    if all(occupied_slots[day].get(slot) is None for slot in slot_pair) and \
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
                        lab_combinations.remove(slot_pair)
                        allocated_periods += 1
                        break
            else:
                possible_slots = [slot for slot in TIME_SLOTS if occupied_slots[day][slot] is None and 
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
                    allocated_periods += 1
                    break
        if allocated_periods < periods_needed:
            break

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








# Define constants
DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
TIME_SLOTS = ["9:30-11:30", "11:30-1:30", "2:00-4:00", "4:00-6:00"]



def get_selected_courses(selected_courses):
    connection = create_connection()
    cursor = connection.cursor(dictionary=True)
    courses = []
    
    for course_id in selected_courses:
        cursor.execute("SELECT * FROM courses WHERE course_id = %s", (course_id,))
        course = cursor.fetchone()
        cursor.execute("SELECT * FROM course_subjects WHERE course_id = %s", (course_id,))
        subjects = cursor.fetchall()
        course['subjects'] = subjects
        courses.append(course)
    
    cursor.close()
    connection.close()
    return courses

@app.route('/timetable')
def timetable():
    if 'admin' in session:
        connection = create_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT * FROM courses")
        courses = cursor.fetchall()
        cursor.close()
        connection.close()
        return render_template(
            'timetable.html', 
            courses=courses, 
            TIME_SLOTS=TIME_SLOTS
        )
    else:
        return redirect(url_for('admin_login'))

@app.route('/generate_timetable', methods=['POST'])
def generate_timetable():
    classroom_availability = int(request.form['classroom_availability'])
    lab_availability = int(request.form['lab_availability'])
    selected_courses = request.form.getlist('selected_courses')

    # Get selected courses from the database or another data source
    courses = get_selected_courses(selected_courses)  # This should return a list of course objects with their subjects and details
    
    # Define parameters for genetic algorithm
    population_size = 50
    num_generations = 20
    num_parents = 2
    mutation_rate = 0.1

    # Generate timetables using the genetic algorithm
    best_timetables = genetic_algorithm(
        courses=courses, 
        population_size=population_size, 
        num_generations=num_generations, 
        num_parents=num_parents, 
        mutation_rate=mutation_rate
    )
    
    # Render the generated timetable
    return render_template(
        'generated_timetable.html',
        timetables=best_timetables,
        TIME_SLOTS=TIME_SLOTS,
        DAYS=DAYS
    )

if __name__ == '__main__':
    app.run(debug=True)




--this code utilizes the friday scheduling 
--allocates required number of lab and theory classes 
--it do not produce clash free teachers allocation 
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







# Define constants
DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
TIME_SLOTS = ["9:30-11:30", "11:30-1:30", "2:00-4:00", "4:00-6:00"]



def get_selected_courses(selected_courses):
    connection = create_connection()
    cursor = connection.cursor(dictionary=True)
    courses = []
    
    for course_id in selected_courses:
        cursor.execute("SELECT * FROM courses WHERE course_id = %s", (course_id,))
        course = cursor.fetchone()
        cursor.execute("SELECT * FROM course_subjects WHERE course_id = %s", (course_id,))
        subjects = cursor.fetchall()
        course['subjects'] = subjects
        courses.append(course)
    
    cursor.close()
    connection.close()
    return courses

@app.route('/timetable')
def timetable():
    if 'admin' in session:
        connection = create_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT * FROM courses")
        courses = cursor.fetchall()
        cursor.close()
        connection.close()
        return render_template(
            'timetable.html', 
            courses=courses, 
            TIME_SLOTS=TIME_SLOTS
        )
    else:
        return redirect(url_for('admin_login'))

@app.route('/generate_timetable', methods=['POST'])
def generate_timetable():
    classroom_availability = int(request.form['classroom_availability'])
    lab_availability = int(request.form['lab_availability'])
    selected_courses = request.form.getlist('selected_courses')

    # Get selected courses from the database or another data source
    courses = get_selected_courses(selected_courses)  # This should return a list of course objects with their subjects and details
    
    # Define parameters for genetic algorithm
    population_size = 50
    num_generations = 20
    num_parents = 2
    mutation_rate = 0.1

    # Generate timetables using the genetic algorithm
    best_timetables = genetic_algorithm(
        courses=courses, 
        population_size=population_size, 
        num_generations=num_generations, 
        num_parents=num_parents, 
        mutation_rate=mutation_rate
    )
    
    # Render the generated timetable
    return render_template(
        'generated_timetable.html',
        timetables=best_timetables,
        TIME_SLOTS=TIME_SLOTS,
        DAYS=DAYS
    )

if __name__ == '__main__':
    app.run(debug=True)



{% extends "base.html" %}

{% block content %}
<section id="generated">
    <h1>Generated Timetable</h1>
    <style>
        .timetable, .timetable th, .timetable td {
            border: 2px solid black; /* Thick and black border */
            border-collapse: collapse; /* Ensures borders are merged */
            padding: 8px; /* Adds some padding inside the cells */
        }
        .timetable th, .timetable td {
            text-align: center; /* Centers text inside cells */
        }
    </style>
    {% for course_id, timetable in timetables.items() %}
        <h2>Course ID: {{ course_id }}</h2>
        <table class="timetable">
            <thead>
                <tr>
                    <th>Day/Time</th>
                    {% for time_slot in TIME_SLOTS %}
                        <th>{{ time_slot }}</th>
                    {% endfor %}
                </tr>
            </thead>
            <tbody>
                {% for day in DAYS %}
                    <tr>
                        <td>{{ day }}</td>
                        {% for time_slot in TIME_SLOTS %}
                            {% set current_entry = timetable.get((day, time_slot)) %}
                            {% if current_entry %}
                                {% if current_entry.colspan == 2 %}
                                    <td colspan="2">{{ current_entry.subject_name }} (Lab) ({{ current_entry.teacher_id }})</td>
                                {% elif current_entry.colspan == 0 %}
                                    {# Skip the cell rendering because it is covered by the previous cell's colspan #}
                                {% else %}
                                    <td>{{ current_entry.subject_name }} ({{ current_entry.teacher_id }})</td>
                                {% endif %}
                            {% else %}
                                <td></td>
                            {% endif %}
                        {% endfor %}
                    </tr>
                {% endfor %}
            </tbody>
        </table>
    {% endfor %}
</section>
{% endblock %}






--this code is almost producing clash free teachers and subjects timetable 
--the fitness score is good in this code
--layout of the timetable looks unarranged 
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
    total_slots = len(DAYS) * len(TIME_SLOTS)
    
    # Create a dictionary to track teacher schedules
    teacher_schedule = {day: {slot: set() for slot in TIME_SLOTS} for day in DAYS}
    
    print("Detailed Timetable:")
    for (day, time_slot), details in timetable.items():
        print(f"Day: {day}, Time Slot: {time_slot}, Subject: {details['subject_name']}, Teacher: {details['teacher_id']}, Type: {details['type']}")
        
        if details['type'] == 'lab':
            if time_slot in teacher_schedule[day]:
                if details['teacher_id'] in teacher_schedule[day][time_slot]:
                    clashes += 1
            teacher_schedule[day][time_slot].add(details['teacher_id'])
            next_slot = TIME_SLOTS[TIME_SLOTS.index(time_slot) + 1] if TIME_SLOTS.index(time_slot) + 1 < len(TIME_SLOTS) else None
            if next_slot:
                if next_slot in teacher_schedule[day]:
                    if details['teacher_id'] in teacher_schedule[day][next_slot]:
                        clashes += 1
                teacher_schedule[day][next_slot].add(details['teacher_id'])
        else:
            if details['teacher_id'] in teacher_schedule[day][time_slot]:
                clashes += 1
            teacher_schedule[day][time_slot].add(details['teacher_id'])
    
    # Calculate fitness
    base_score = total_slots - clashes
    fitness = base_score - (clashes * 5)  # Adjusted penalty for each clash

    print(f"Total Clashes: {clashes}")
    return fitness



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
    # Perform mutation by removing random entries and re-adding them
    mutated_timetable = copy.deepcopy(timetable)
    for _ in range(int(mutation_rate * len(timetable))):
        key = random.choice(list(mutated_timetable.keys()))
        day = random.choice(DAYS)
        time_slot = random.choice(TIME_SLOTS)
        mutated_timetable[key] = mutated_timetable.get(key, {'subject_name': 'N/A', 'teacher_id': 'N/A'})
        mutated_timetable[key]['day'] = day
        mutated_timetable[key]['time_slot'] = time_slot
    return mutated_timetable

def genetic_algorithm(courses, population_size, num_generations, num_parents, mutation_rate):
    global teacher_availability
    best_timetables = {}
    
    for course in courses:
        print(f"Processing course: {course['course_id']}")
        
        teacher_availability = {day: {slot: None for slot in TIME_SLOTS} for day in DAYS}
        population = initialize_population(population_size, course['subjects'])
        
        for generation in range(num_generations):
            print(f" Generation {generation + 1}")
            
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

        # Print the best timetable for the course
        print(f"Best timetable for course {course['course_id']}:")
        for (day, time_slot), details in best_timetable.items():
            print(f"  Day: {day}, Slot: {time_slot}, Subject: {details['subject_name']}, Teacher: {details['teacher_id']}, Type: {details['type']}")
        
        # Print fitness of the best timetable
        best_fitness = calculate_fitness(best_timetable)
        print(f"Fitness of best timetable for course {course['course_id']}: {best_fitness}")
    
    return best_timetables



# Define constants
DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
TIME_SLOTS = ["9:30-11:30", "11:30-1:30", "2:00-4:00", "4:00-6:00"]



def get_selected_courses(selected_courses):
    connection = create_connection()
    cursor = connection.cursor(dictionary=True)
    courses = []
    
    for course_id in selected_courses:
        cursor.execute("SELECT * FROM courses WHERE course_id = %s", (course_id,))
        course = cursor.fetchone()
        cursor.execute("SELECT * FROM course_subjects WHERE course_id = %s", (course_id,))
        subjects = cursor.fetchall()
        course['subjects'] = subjects
        courses.append(course)
    
    cursor.close()
    connection.close()
    return courses

@app.route('/timetable')
def timetable():
    if 'admin' in session:
        connection = create_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT * FROM courses")
        courses = cursor.fetchall()
        cursor.close()
        connection.close()
        return render_template(
            'timetable.html', 
            courses=courses, 
            TIME_SLOTS=TIME_SLOTS
        )
    else:
        return redirect(url_for('admin_login'))

@app.route('/generate_timetable', methods=['POST'])
def generate_timetable():
    classroom_availability = int(request.form['classroom_availability'])
    lab_availability = int(request.form['lab_availability'])
    selected_courses = request.form.getlist('selected_courses')

    # Get selected courses from the database or another data source
    courses = get_selected_courses(selected_courses)  # This should return a list of course objects with their subjects and details
    
    # Define parameters for genetic algorithm
    population_size = 50
    num_generations = 20
    num_parents = 2
    mutation_rate = 0.1

    # Generate timetables using the genetic algorithm
    best_timetables = genetic_algorithm(
        courses=courses, 
        population_size=population_size, 
        num_generations=num_generations, 
        num_parents=num_parents, 
        mutation_rate=mutation_rate
    )
    
    # Render the generated timetable
    return render_template(
        'generated_timetable.html',
        timetables=best_timetables,
        TIME_SLOTS=TIME_SLOTS,
        DAYS=DAYS
    )

if __name__ == '__main__':
    app.run(debug=True)















--the below code gives you the teachers clash free timetable and generates timetable only for theory excluding the lab


import random
import copy
import mysql.connector
from collections import defaultdict

# Define days and time slots
DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
TIME_SLOTS = ["9:30-11:30", "11:30-1:30", "2:00-4:00", "4:00-6:00"]

def get_teacher_ids_from_db():
    conn = mysql.connector.connect(
        host="localhost",
        user="root",
        password="admin",
        database="class_scheduler"
    )
    cursor = conn.cursor()
    cursor.execute("SELECT id FROM teachers")
    teacher_ids = [row[0] for row in cursor.fetchall()]
    cursor.close()
    conn.close()
    return teacher_ids

teacher_ids = get_teacher_ids_from_db()

# Global teacher availability across all courses
global_teacher_availability = {teacher_id: {day: set(TIME_SLOTS) for day in DAYS} for teacher_id in teacher_ids}

def initialize_population(population_size, subjects):
    population = []
    for _ in range(population_size):
        timetable = generate_individual_timetable(subjects)
        population.append(timetable)
    return population

def generate_individual_timetable(subjects):
    timetable = {}
    local_teacher_availability = copy.deepcopy(global_teacher_availability)
    for subject in subjects:
        periods_needed = 2 if 'lab' in subject['subject_type'] else 2
        allocate_periods(periods_needed, subject, timetable, local_teacher_availability)
    return timetable

def allocate_periods(periods_needed, subject, timetable, teacher_availability):
    allocated_periods = 0
    teacher_id = subject['teacher_id']
    available_days = list(teacher_availability[teacher_id].keys())
    random.shuffle(available_days)  # Randomize the days to reduce bias

    while allocated_periods < periods_needed and available_days:
        day = available_days.pop()
        available_slots = teacher_availability[teacher_id][day]
        if available_slots:
            time_slot = random.choice(list(available_slots))
            timetable[(day, time_slot)] = {
                'subject_name': subject['subject_name'],
                'teacher_id': teacher_id,
                'type': subject['subject_type']
            }
            # Update availability
            teacher_availability[teacher_id][day].remove(time_slot)
            global_teacher_availability[teacher_id][day].remove(time_slot)
            allocated_periods += 1

def calculate_fitness(timetable):
    clashes = 0
    teacher_schedule = defaultdict(lambda: defaultdict(set))
    
    for (day, time_slot), details in timetable.items():
        teacher = details['teacher_id']
        if time_slot in teacher_schedule[teacher][day]:
            clashes += 1
        teacher_schedule[teacher][day].add(time_slot)
    
    return -clashes

def selection(population, fitnesses, num_parents):
    total_fitness = sum(fitnesses)
    if total_fitness == 0:
        return random.sample(population, num_parents)
    weights = [f / total_fitness for f in fitnesses]
    return random.choices(population, weights=weights, k=num_parents)

def crossover(parent1, parent2):
    child = copy.deepcopy(parent1)
    if parent1:
        crossover_point = random.randint(0, len(parent1) - 1)
    else:
        crossover_point = 0
    for i, key in enumerate(parent2):
        if i > crossover_point and key not in child:
            day, time_slot = key
            teacher_id = parent2[key]['teacher_id']
            if time_slot in global_teacher_availability[teacher_id][day]:
                child[key] = parent2[key]
                global_teacher_availability[teacher_id][day].remove(time_slot)
    return child

def mutate(timetable, mutation_rate):
    for key in list(timetable.keys()):
        if random.random() < mutation_rate:
            day = random.choice(DAYS)
            time_slot = random.choice(TIME_SLOTS)
            teacher_id = timetable[key]['teacher_id']
            if time_slot in global_teacher_availability[teacher_id].get(day, set()):
                # Remove the old slot from global availability
                old_day, old_time_slot = key
                if old_time_slot in global_teacher_availability[teacher_id][old_day]:
                    global_teacher_availability[teacher_id][old_day].add(old_time_slot)
                # Assign new slot
                timetable[(day, time_slot)] = timetable.pop(key)
                timetable[(day, time_slot)]['teacher_id'] = teacher_id
                global_teacher_availability[teacher_id][day].remove(time_slot)
    return timetable

def genetic_algorithm(courses, population_size, num_generations, num_parents, mutation_rate):
    global global_teacher_availability
    best_timetables = {}
    
    # Backup initial global teacher availability to restore later
    initial_global_availability = copy.deepcopy(global_teacher_availability)
    
    for course in courses:
        population = initialize_population(population_size, course['subjects'])
        for generation in range(num_generations):
            fitnesses = [calculate_fitness(individual) for individual in population]
            if all(f <= 0 for f in fitnesses):
                fitnesses[0] = 1

            new_population = []
            for _ in range(population_size):
                parents = selection(population, fitnesses, num_parents)
                if len(parents) < 2:
                    continue
                child = crossover(parents[0], parents[1])
                child = mutate(child, mutation_rate)
                new_population.append(child)
            population = new_population

        best_timetable = max(population, key=calculate_fitness)
        best_timetables[course['course_id']] = best_timetable
    
    # Restore global availability after processing all courses
    global_teacher_availability = initial_global_availability
    
    return best_timetables









# Define constants
DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
TIME_SLOTS = ["9:30-11:30", "11:30-1:30", "2:00-4:00", "4:00-6:00"]



def get_selected_courses(selected_courses):
    connection = create_connection()
    cursor = connection.cursor(dictionary=True)
    courses = []
    
    for course_id in selected_courses:
        cursor.execute("SELECT * FROM courses WHERE course_id = %s", (course_id,))
        course = cursor.fetchone()
        cursor.execute("SELECT * FROM course_subjects WHERE course_id = %s", (course_id,))
        subjects = cursor.fetchall()
        course['subjects'] = subjects
        courses.append(course)
    
    cursor.close()
    connection.close()
    return courses

@app.route('/timetable')
def timetable():
    if 'admin' in session:
        connection = create_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT * FROM courses")
        courses = cursor.fetchall()
        cursor.close()
        connection.close()
        return render_template(
            'timetable.html', 
            courses=courses, 
            TIME_SLOTS=TIME_SLOTS
        )
    else:
        return redirect(url_for('admin_login'))

@app.route('/generate_timetable', methods=['POST'])
def generate_timetable():
    classroom_availability = int(request.form['classroom_availability'])
    lab_availability = int(request.form['lab_availability'])
    selected_courses = request.form.getlist('selected_courses')

    # Get selected courses from the database or another data source
    courses = get_selected_courses(selected_courses)  # This should return a list of course objects with their subjects and details
    
    # Define parameters for genetic algorithm
    population_size = 100
    num_generations = 50
    num_parents = 2
    mutation_rate = 0.1

    # Generate timetables using the genetic algorithm
    best_timetables = genetic_algorithm(
        courses=courses, 
        population_size=population_size, 
        num_generations=num_generations, 
        num_parents=num_parents, 
        mutation_rate=mutation_rate
    )
    
    # Render the generated timetable
    return render_template(
        'generated_timetable.html',
        timetables=best_timetables,
        TIME_SLOTS=TIME_SLOTS,
        DAYS=DAYS
    )

if __name__ == '__main__':
    app.run(debug=True)
