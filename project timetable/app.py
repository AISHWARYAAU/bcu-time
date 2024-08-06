from flask import Flask, render_template, request, redirect, url_for, flash, session, jsonify
from genetic_algorithm import DAYS, TIME_SLOTS, genetic_algorithm
import mysql.connector
from mysql.connector import Error, IntegrityError
import streamlit as st
import numpy as np
from deap import base, creator, tools, algorithms

from sqlalchemy import create_engine, Column, String, Integer, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, scoped_session, relationship
import random



app = Flask(__name__)
app.secret_key = 'your_secret_key'

# Database connection 
def create_connection():
    connection = None
    try:
        connection = mysql.connector.connect(
            host='localhost',
            user='root',  #  MySQL username
            password='admin1',  # MySQL root password
            database='class_scheduler'
        )
        if connection.is_connected():
            print("Connection to MySQL DB successful")
    except Error as e:
        print(f"The error '{e}' occurred")
    return connection

# Create SQLAlchemy engine
DATABASE_URI = 'mysql+pymysql://root:password@localhost/class_scheduler'
engine = create_engine(DATABASE_URI, echo=True)  # Set echo=True for debugging
# Establish MySQL connection
connection = create_connection()
Base = declarative_base()
Session = sessionmaker(bind=engine)
db_session = scoped_session(Session)


@app.route('/dashboard')
def dashboard():
    if 'admin' in session:
        return render_template('dashboard.html')
    else:
        return redirect(url_for('admin_login'))
    

@app.route('/edit_course/<string:course_id>', methods=['GET', 'POST'])
def edit_course(course_id):
    if 'admin' in session:
        try:
            connection = create_connection()
            cursor = connection.cursor(dictionary=True)
            
            # Fetch departments and semesters for dropdowns
            cursor.execute("SELECT name FROM departments")
            departments = cursor.fetchall()
            cursor.execute("SELECT name FROM semesters")
            semesters = cursor.fetchall()

            if request.method == 'POST':
                # Handle form submission to update course details
                department = request.form['department']
                course_name = request.form['course_name']
                semester = request.form['semester']
                new_course_id = request.form['new_course_id']  # Updated course_id
                
                cursor.execute("""
                    UPDATE courses 
                    SET department = %s, course_name = %s, semester = %s, course_id = %s
                    WHERE course_id = %s
                """, (department, course_name, semester, new_course_id, course_id))

                connection.commit()

                flash(f'Course {new_course_id} updated successfully', 'success')
                return redirect(url_for('courses'))

            else:
                # Fetch existing course details for editing
                cursor.execute("SELECT * FROM courses WHERE course_id = %s", (course_id,))
                course = cursor.fetchone()

                cursor.close()
                connection.close()

                return render_template('edit_course.html', course=course, departments=departments, semesters=semesters)

        except mysql.connector.Error as error:
            print(f"Error with MySQL: {error}")
            flash('Error updating course', 'error')

        return redirect(url_for('courses'))  # Redirect to courses page on error or GET request

    else:
        return redirect(url_for('admin_login'))



@app.route('/add_course', methods=['GET', 'POST'])
def add_course():
    if 'admin' in session:
        connection = create_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT name FROM departments")
        departments = cursor.fetchall()
        cursor.execute("SELECT name FROM semesters")
        semesters = cursor.fetchall()
        cursor.close()

        if request.method == 'POST':
            department = request.form['department']
            course_name = request.form['course_name']
            semester = request.form['semester']
            course_id = request.form['course_id']
            
            cursor = connection.cursor()
            cursor.execute("INSERT INTO courses (department, course_name, semester, course_id) VALUES (%s, %s, %s, %s)", 
                           (department, course_name, semester, course_id))
            connection.commit()
            cursor.close()
            connection.close()
            return redirect(url_for('courses'))
        return render_template('add_course.html', departments=departments, semesters=semesters)
    else:
        return redirect(url_for('admin_login'))

@app.route('/delete_course/<course_id>', methods=['POST'])
def delete_course(course_id):
    if 'admin' in session:
        connection = create_connection()
        cursor = connection.cursor()
        cursor.execute("DELETE FROM courses WHERE course_id = %s", (course_id,))
        connection.commit()
        cursor.close()
        connection.close()
        return redirect(url_for('courses'))
    else:
        return redirect(url_for('admin_login'))

@app.route('/add_course_details', methods=['GET', 'POST'])
def add_course_details():
    if 'admin' in session:
        try:
            if request.method == 'POST':
                # Handle form submission to add course subject
                course_id = request.form['course_id']
                subject_id = request.form['subject_id']
                subject_name = request.form['subject_name']
                teacher_id = request.form['teacher_id']
                teacher_name = request.form['teacher_name']
                subject_type = request.form['subject_type']
                working_hours = request.form['working_hours']

                # Insert into database
                connection = create_connection()
                cursor = connection.cursor()
                cursor.execute("""
                    INSERT INTO course_subjects 
                    (course_id, subject_id, subject_name, teacher_id, teacher_name, subject_type, working_hours) 
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                """, (course_id, subject_id, subject_name, teacher_id, teacher_name, subject_type, working_hours))
                connection.commit()

                # Clean up
                cursor.close()
                connection.close()

                flash('Course subject added successfully', 'success')
                return redirect(url_for('view_course', course_id=course_id))

            elif request.method == 'GET':
                course_id = request.args.get('course_id')

                # Fetch subjects and teachers for dropdowns
                connection = create_connection()
                cursor = connection.cursor(dictionary=True)
                cursor.execute("SELECT subjectid, subject_name, subject_type FROM subjects")
                subjects = cursor.fetchall()
                cursor.execute("SELECT id, name FROM teachers")
                teachers = cursor.fetchall()
                cursor.close()
                connection.close()

                return render_template('add_course_details.html', subjects=subjects, teachers=teachers)

        except mysql.connector.Error as error:
            print(f"Error with MySQL: {error}")
            flash('Error adding course subject', 'error')

        return redirect(url_for('add_course_details'))
    else:
        return redirect(url_for('login'))

@app.route('/view_course/<string:course_id>', methods=['GET'])
def view_course(course_id):
    # Ensure course_id is handled as a string here

    if 'admin' in session:
        try:
            connection = create_connection()
            cursor = connection.cursor(dictionary=True)

            # Fetch the course details
            cursor.execute("SELECT * FROM courses WHERE course_id = %s", (course_id,))
            course = cursor.fetchone()

            if course is None:
                flash('Course not found', 'error')
                return redirect(url_for('admin_dashboard'))  # Adjust as per your dashboard route

            # Fetch subjects for the selected course
            cursor.execute("SELECT * FROM course_subjects WHERE course_id = %s", (course_id,))
            subjects = cursor.fetchall()

            cursor.close()
            connection.close()

            return render_template('view_course.html', course=course, subjects=subjects)

        except mysql.connector.Error as error:
            print(f"Error with MySQL: {error}")
            flash('Error fetching course details', 'error')
            return redirect(url_for('admin_login'))

    else:
        return redirect(url_for('admin_login'))



@app.route('/edit_course_subject/<int:subject_id>', methods=['GET', 'POST'])
def edit_course_subject(subject_id):
    if 'admin' in session:
        try:
            connection = create_connection()
            cursor = connection.cursor(dictionary=True)

            if request.method == 'POST':
                # Get form data
                subject_name = request.form['subject_name']
                teacher_id = request.form['teacher_id']
                teacher_name = request.form['teacher_name']
                subject_type = request.form['subject_type']
                working_hours = request.form['working_hours']

                # Update the course_subjects table
                cursor.execute("""
                    UPDATE course_subjects 
                    SET subject_name = %s, teacher_id = %s, teacher_name = %s, subject_type = %s, working_hours = %s 
                    WHERE subject_id = %s
                """, (subject_name, teacher_id, teacher_name, subject_type, working_hours, subject_id))

                connection.commit()
                cursor.close()
                connection.close()

                flash('Course subject updated successfully', 'success')
                return redirect(url_for('view_course', course_id=request.form['course_id']))

            # If GET, fetch the subject details to display in the form
            cursor.execute("SELECT * FROM course_subjects WHERE subject_id = %s", (subject_id,))
            subject = cursor.fetchone()

            if subject is None:
                flash('Subject not found', 'error')
                return redirect(url_for('view_course'))  # Adjust as per your requirement

            cursor.close()
            connection.close()

            return render_template('edit_course_subject.html', subject=subject)

        except mysql.connector.Error as error:
            print(f"Error with MySQL: {error}")
            flash('Error updating course subject', 'error')
            return redirect(url_for('view_course'))
    else:
        return redirect(url_for('admin_login'))


@app.route('/delete_course_subject/<int:subject_id>', methods=['POST'])
def delete_course_subject(subject_id):
    if 'admin' in session:
        try:
            connection = create_connection()
            cursor = connection.cursor()

            # Get course_id before deleting
            cursor.execute("SELECT course_id FROM course_subjects WHERE subject_id = %s", (subject_id,))
            course_id_result = cursor.fetchone()

            if course_id_result is None:
                flash('Subject not found', 'error')
                return redirect(url_for('view_course'))  # Adjust as per your requirement

            course_id = course_id_result[0]

            # Delete the course subject from the database
            cursor.execute("DELETE FROM course_subjects WHERE subject_id = %s", (subject_id,))

            connection.commit()
            cursor.close()
            connection.close()

            flash('Course subject deleted successfully', 'success')
            return redirect(url_for('view_course', course_id=course_id))

        except mysql.connector.Error as error:
            print(f"Error with MySQL: {error}")
            flash('Error deleting course subject', 'error')
            return redirect(url_for('view_course'))
    else:
        return redirect(url_for('admin_login'))


# Route to display all teachers
@app.route('/teachers')
def teachers():
    try:
        connection = create_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT * FROM teachers")
        teachers = cursor.fetchall()
        cursor.close()
        connection.close()
        return render_template('teachers.html', teachers=teachers)
    except mysql.connector.Error as error:
        print(f"Error fetching teachers: {error}")
        flash('Error fetching teachers', 'error')
        return redirect(url_for('admin_login'))

# Route to display add teacher form and handle form submission
@app.route('/add_teacher', methods=['GET', 'POST'])
def add_teacher():
    if 'admin' in session:  # Ensure admin is logged in
        if request.method == 'POST':
            try:
                # Fetch form data
                teacher_id = request.form['id']
                name = request.form['name']
                working_hours = request.form['working_hours']

                # Establish connection
                connection = create_connection()
                cursor = connection.cursor()

                # Insert new teacher into database
                insert_query = "INSERT INTO teachers (id, name, working_hours) VALUES (%s, %s, %s)"
                cursor.execute(insert_query, (teacher_id, name, working_hours))
                connection.commit()

                # Close cursor and connection
                cursor.close()
                connection.close()

                flash('Teacher added successfully', 'success')
                return redirect(url_for('teachers'))

            except mysql.connector.Error as error:
                print(f"Error adding teacher: {error}")
                flash('Error adding teacher', 'error')

        return render_template('add_teacher.html')

    else:
        return redirect(url_for('admin_login'))  # Redirect if not logged in as admin

# Route to edit a teacher
@app.route('/edit_teacher/<teacher_id>', methods=['GET', 'POST'])
def edit_teacher(teacher_id):
    if 'admin' in session:
        if request.method == 'POST':
            name = request.form['name']
            working_hours = request.form['working_hours']
            try:
                connection = create_connection()
                cursor = connection.cursor()
                update_query = "UPDATE teachers SET name = %s, working_hours = %s WHERE id = %s"
                cursor.execute(update_query, (name, working_hours, teacher_id))
                connection.commit()
                cursor.close()
                connection.close()
                flash('Teacher updated successfully', 'success')
                return redirect(url_for('teachers'))
            except mysql.connector.Error as error:
                print(f"Error updating teacher: {error}")
                flash('Error updating teacher', 'error')
        try:
            connection = create_connection()
            cursor = connection.cursor(dictionary=True)
            select_query = "SELECT * FROM teachers WHERE id = %s"
            cursor.execute(select_query, (teacher_id,))
            teacher = cursor.fetchone()
            cursor.close()
            connection.close()
            return render_template('edit_teacher.html', teacher=teacher)
        except mysql.connector.Error as error:
            print(f"Error fetching teacher: {error}")
            flash('Error fetching teacher', 'error')
            return redirect(url_for('teachers'))
    else:
        return redirect(url_for('admin_login'))
    

@app.route('/delete_teacher/<teacher_id>', methods=['POST'])
def delete_teacher(teacher_id):
    if 'admin' in session:
        try:
            # Establish connection
            connection = create_connection()
            cursor = connection.cursor()

            # Delete teacher from database
            delete_query = "DELETE FROM teachers WHERE id = %s"
            cursor.execute(delete_query, (teacher_id,))
            connection.commit()

            # Close cursor and connection
            cursor.close()
            connection.close()

            flash('Teacher deleted successfully', 'success')
        except mysql.connector.Error as error:
            print(f"Error deleting teacher: {error}")
            flash('Error deleting teacher', 'error')

        return redirect(url_for('teachers'))  # Redirect back to teachers list
    else:
        return redirect(url_for('admin_login'))  # Redirect if not logged in as admin

@app.route('/subjects')
def subjects():
    if 'admin' in session:
        connection = create_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT subjectid, subject_name, subject_type FROM subjects")
        subjects = cursor.fetchall()
        cursor.close()
        connection.close()
        
        # Debug print statement
        print("Fetched subjects:", subjects)

        return render_template('subjects.html', subjects=subjects)
    else:
        return redirect(url_for('admin_login'))

@app.route('/add_subject', methods=['GET', 'POST'])
def add_subject():
    if 'admin' in session:
        if request.method == 'POST':
            subject_id = request.form['subjectid']
            subject_name = request.form['subject_name']
            subject_type = request.form['subject_type']

            connection = create_connection()
            cursor = connection.cursor()

            insert_query = "INSERT INTO subjects (subjectid, subject_name, subject_type) VALUES (%s, %s, %s)"
            try:
                cursor.execute(insert_query, (subject_id, subject_name, subject_type))
                connection.commit()
                flash('Subject added successfully', 'success')
                
                # Debug print statement
                print(f"Added subject: {subject_id}, {subject_name}, {subject_type}")

            except IntegrityError as e:
                if e.errno == 1062:  # MySQL error number for duplicate entry
                    flash(f'Subject ID {subject_id} already exists. Please choose a different ID.', 'error')
                else:
                    flash('An error occurred while adding the subject. Please try again.', 'error')
            except Exception as e:
                flash('An error occurred while adding the subject. Please try again.', 'error')
            finally:
                cursor.close()
                connection.close()

            return redirect(url_for('subjects'))

        return render_template('add_subject.html')
    else:
        return redirect(url_for('admin_login'))

@app.route('/edit_subject/<subjectid>', methods=['GET', 'POST'])
def edit_subject(subjectid):
    if 'admin' in session:
        connection = create_connection()
        cursor = connection.cursor(dictionary=True)

        if request.method == 'POST':
            subject_name = request.form['subject_name']
            subject_type = request.form['subject_type']
            cursor.execute('''
                UPDATE subjects
                SET subject_name = %s, subject_type = %s
                WHERE subjectid = %s
            ''', (subject_name, subject_type, subjectid))
            connection.commit()
            cursor.close()
            connection.close()
            flash('Subject updated successfully', 'success')
            return redirect(url_for('subjects'))

        cursor.execute('SELECT * FROM subjects WHERE subjectid = %s', (subjectid,))
        subject = cursor.fetchone()
        cursor.close()
        connection.close()
        
        if subject:
            return render_template('edit_subject.html', subject=subject)
        else:
            flash('Subject not found.', 'error')
            return redirect(url_for('subjects'))
    else:
        return redirect(url_for('admin_login'))

@app.route('/delete_subject/<subjectid>', methods=['POST'])
def delete_subject(subjectid):
    if 'admin' in session:
        connection = create_connection()
        cursor = connection.cursor()
        cursor.execute('DELETE FROM subjects WHERE subjectid = %s', (subjectid,))
        connection.commit()
        cursor.close()
        connection.close()
        flash('Subject deleted successfully', 'success')
        return redirect(url_for('subjects'))
    else:
        return redirect(url_for('admin_login'))
    



@app.route('/departments')
def departments():
    if 'admin' in session:
        connection = create_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT * FROM departments")
        departments = cursor.fetchall()
        return render_template('departments.html', departments=departments)
    else:
        return redirect(url_for('admin_login'))

# Route to add a new department
@app.route('/add_department', methods=['GET', 'POST'])
def add_department():
    if 'admin' in session:
        if request.method == 'POST':
            id = request.form['id']
            name = request.form['name']

            connection = create_connection()
            cursor = connection.cursor()

            insert_query = "INSERT INTO departments (id, name) VALUES (%s, %s)"
            try:
                cursor.execute(insert_query, (id, name))
                connection.commit()
                flash('Department added successfully', 'success')  # Flash success message
            except IntegrityError as e:
                if e.errno == 1062:  # MySQL error number for duplicate entry
                    flash(f'Department ID {id} already exists. Please choose a different ID.', 'error')
                else:
                    flash('An error occurred while adding the department. Please try again.', 'error')
            
            # Close cursor and connection
            cursor.close()
            connection.close()

            return redirect(url_for('departments'))

        return render_template('add_department.html')
    else:
        return redirect(url_for('admin_login'))



@app.route('/edit_department/<string:department_id>', methods=['GET', 'POST'])
def edit_department(department_id):
    if 'admin' in session:
        connection = create_connection()
        cursor = connection.cursor(dictionary=True)

        if request.method == 'POST':
            name = request.form['name']

            update_query = "UPDATE departments SET name = %s WHERE id = %s"
            cursor.execute(update_query, (name, department_id))
            connection.commit()

            flash('Department updated successfully')
            return redirect(url_for('departments'))

        cursor.execute("SELECT * FROM departments WHERE id = %s", (department_id,))
        department = cursor.fetchone()

        return render_template('edit_department.html', department=department)
    else:
        return redirect(url_for('admin_login'))

# Route to delete a department
@app.route('/delete_department/<string:department_id>')
def delete_department(department_id):
    if 'admin' in session:
        connection = create_connection()
        cursor = connection.cursor()

        delete_query = "DELETE FROM departments WHERE id = %s"
        cursor.execute(delete_query, (department_id,))
        connection.commit()

        flash('Department deleted successfully')
        return redirect(url_for('departments'))
    else:
        return redirect(url_for('admin_login'))


@app.route('/semesters')
def semesters():
    if 'admin' in session:
        connection = create_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT * FROM semesters")
        semesters = cursor.fetchall()
        cursor.close()
        connection.close()
        return render_template('semesters.html', semesters=semesters)
    else:
        return redirect(url_for('admin_login'))

@app.route('/add_semester', methods=['GET', 'POST'])
def add_semester():
    if 'admin' in session:
        if request.method == 'POST':
            semester_id = request.form['semester_id']
            semester_name = request.form['semester_name']

            connection = create_connection()
            cursor = connection.cursor()

            insert_query = "INSERT INTO semesters (id, name) VALUES (%s, %s)"
            try:
                cursor.execute(insert_query, (semester_id, semester_name))
                connection.commit()
                flash('Semester added successfully', 'success')
            except IntegrityError as e:
                if e.errno == 1062:  # MySQL error number for duplicate entry
                    flash(f'Semester ID "{semester_id}" or Semester name "{semester_name}" already exists. Please choose different values.', 'error')
                else:
                    flash('An error occurred while adding the semester. Please try again.', 'error')
            finally:
                cursor.close()
                connection.close()

            return redirect(url_for('semesters'))

        return render_template('add_semester.html')
    else:
        return redirect(url_for('admin_login'))

@app.route('/edit_semester/<int:semester_id>', methods=['GET', 'POST'])
def edit_semester(semester_id):
    if 'admin' in session:
        if request.method == 'POST':
            new_name = request.form['semestername']

            connection = create_connection()
            cursor = connection.cursor()

            update_query = "UPDATE semesters SET name = %s WHERE id = %s"
            try:
                cursor.execute(update_query, (new_name, semester_id))
                connection.commit()
                flash('Semester updated successfully', 'success')
                return redirect(url_for('semesters'))
            except IntegrityError as e:
                flash(f'An error occurred while updating the semester: {e}', 'error')

            cursor.close()
            connection.close()

        # Fetch existing semester details
        connection = create_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT * FROM semesters WHERE id = %s", (semester_id,))
        semester = cursor.fetchone()
        cursor.close()
        connection.close()

        return render_template('edit_semester.html', semester=semester)
    else:
        return redirect(url_for('admin_login'))

@app.route('/delete_semester/<int:semester_id>')
def delete_semester(semester_id):
    if 'admin' in session:
        connection = create_connection()
        cursor = connection.cursor()

        delete_query = "DELETE FROM semesters WHERE id = %s"
        cursor.execute(delete_query, (semester_id,))
        connection.commit()

        flash('Semester deleted successfully', 'success')

        cursor.close()
        connection.close()

        return redirect(url_for('semesters'))
    else:
        return redirect(url_for('admin_login'))


@app.route('/preferences')
def preferences():
    if 'admin' in session:
        return render_template('preferences.html')
    else:
        return redirect(url_for('admin_login'))

@app.route('/constraints')
def constraints():
    if 'admin' in session:
        return render_template('constraints.html')
    else:
        return redirect(url_for('admin_login'))

@app.route('/user_management')
def user_management():
    if 'admin' in session:
        return render_template('user_management.html')
    else:
        return redirect(url_for('admin_login'))

@app.route('/settings')
def settings():
    if 'admin' in session:
        return render_template('settings.html')
    else:
        return redirect(url_for('admin_login'))

@app.route('/notifications')
def notifications():
    if 'admin' in session:
        return render_template('notifications.html')
    else:
        return redirect(url_for('admin_login'))

@app.route('/reports')
def reports():
    if 'admin' in session:
        return render_template('reports.html')
    else:
        return redirect(url_for('admin_login'))

@app.route('/import_export')
def import_export():
    if 'admin' in session:
        return render_template('import_export.html')
    else:
        return redirect(url_for('admin_login'))


# Existing routes for login/logout and home
@app.route('/')
def home():
    return render_template('index.html')

@app.route('/admin_login', methods=['GET', 'POST'])
def admin_login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']

        connection = create_connection()
        cursor = connection.cursor(dictionary=True)

        query = "SELECT * FROM admins WHERE username = %s AND password = %s"
        cursor.execute(query, (username, password))
        admin = cursor.fetchone()

        if admin:
            session['admin'] = admin['username']
            return redirect(url_for('dashboard'))
        else:
            flash('Invalid username or password')
            return redirect(url_for('admin_login'))

    return render_template('admin_login.html')


@app.route('/courses')
def courses():
    if 'admin' in session:
        connection = create_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT * FROM courses")
        courses = cursor.fetchall()
        cursor.close()
        connection.close()
        return render_template('courses.html', courses=courses)
    else:
        return redirect(url_for('admin_login'))

















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
