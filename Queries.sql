USE film_rental;
-- NOTE:-
SET sql_mode=(SELECT REPLACE(@@sql_mode,'ONLY_FULL_GROUP_BY',''));

-- ########################################################################
-- 1.What is the total revenue generated from all rentals in the database?.
-- ########################################################################

SELECT SUM(amount) AS TotalRevenue FROM payment;

-- #################################################
-- 2.How many rentals were made in each month_name?.
-- #################################################

SELECT 
    MONTH(rental_date ) AS months,
    rental_id, COUNT(*) AS no_of_rentals
FROM rental 
GROUP BY months,rental_id
ORDER BY rental_id;

    
-- ##############################################################################    
-- 3.What is the rental rate of the film with the longest title in the database?.
-- ##############################################################################

SELECT title, rental_rate 
FROM film
WHERE LENGTH(TITLE) = (SELECT MAX(LENGTH(title)) FROM  film)
ORDER BY title;

-- #################################################################################
-- 4.What is the average rental rate for films that were taken from the last 30 days 
--   from the date("2005-05-05 22:04:30")?.
-- #################################################################################

SELECT AVG(rental_rate) FROM film
JOIN inventory USING(film_id)
JOIN rental USING (inventory_id)
WHERE rental_id IN
(SELECT rental_id FROM rental
 WHERE rental_date BETWEEN "2005-05-05 22:04:30" AND DATE_ADD("2005-05-05 22:04:30",INTERVAL 30 DAY));

-- ################################################################################
-- 5.What is the most popular category of films in terms of the number of rentals?. 
-- ################################################################################

SELECT Name AS Name, COUNT(rental_id) AS Rental_Count
FROM category 
INNER JOIN FILM_CATEGORY
USING (category_id)
INNER JOIN FILM
USING (FILM_ID)
INNER JOIN inventory
USING (FILM_ID)
INNER JOIN Rental 
USING (inventory_id)
GROUP BY name
ORDER BY count(rental_id) DESC
LIMIT 1;

-- ###################################################################################################
-- 6.Find the longest movie duration from the list of films that have not been rented by any customer. 
-- ###################################################################################################

SELECT MAX(length) AS MovieDuration
    FROM film
    WHERE film_id NOT IN
(SELECT  film_id
    FROM rental JOIN inventory 
    ON rental.inventory_id = inventory.inventory_id
    WHERE customer_id IN
(SELECT customer.customer_id
    FROM customer 
    WHERE customer.customer_id = rental.customer_id
    GROUP BY customer.customer_id
    HAVING COUNT(rental.rental_id) IS NOT NULL));


-- ######################################################################
-- 7.What is the average rental rate for films, broken down by category?.
-- ###################################################################### 

SELECT c.name AS genre, ROUND(AVG(f.rental_rate),2) AS Average_rental_rate FROM category c
JOIN film_category fc
USING(category_id)
JOIN film f
USING(film_id)
GROUP BY genre
ORDER BY Average_rental_rate DESC;


-- ###################################################################################
-- 8.What is the total revenue generated from rentals for each actor in the database?. 
-- ###################################################################################

SELECT DISTINCT first_name AS Actor, SUM(amount) AS TotalRevenue
FROM payment  
INNER JOIN rental 
USING (rental_id)
INNER JOIN inventory
USING (inventory_id) 
INNER JOIN film_actor
USING (film_id)
INNER JOIN actor
USING (actor_id)
GROUP BY actor
ORDER BY totalrevenue DESC;


-- #####################################################################################
-- 9.Show all the actresses who worked in a film having a "Wrestler" in the description. 
-- #####################################################################################

SELECT DISTINCT first_name AS actresses 
FROM actor WHERE actor_id IN
(SELECT actor_id FROM film_actor WHERE film_id IN
(SELECT film_id FROM film WHERE description LIKE '%wrestler%'));

-- #############################################################
-- 10.Which customers have rented the same film more than once?.
-- #############################################################

WITH temp AS
(SELECT rental_id, rental_date, customer_id, film_id
FROM rental  JOIN inventory
ON rental.inventory_id = inventory.inventory_id)

SELECT t1.customer_id, COUNT(t1.film_id) as filmcount
FROM temp t1 JOIN temp t2
ON t1.customer_id = t2.customer_id AND
t1.film_id = t2.film_id AND
t1.rental_date <> t2.rental_date
GROUP BY t1.customer_id
HAVING COUNT(t1.film_id) > 1;

-- ################################################################################################
-- 11.How many films in the comedy category have a rental rate higher than the average rental rate.
-- ################################################################################################

WITH 
table1(RentalRate,CountofFilms)AS
   (SELECT f.rental_rate AS RentalRate, COUNT(f.film_id) CountofFilms
    FROM film f
    JOIN film_category fa
    ON f.film_id = fa.film_id
    JOIN category c
    ON fa.category_id = c.category_id
    WHERE c.name = 'comedy'
    GROUP BY rental_rate),
table2(AvgRentalRate) as
    (SELECT AVG(rental_rate) AS AvgRentalRate FROM film)
SELECT Rentalrate , CountofFilms FROM table1, table2
WHERE table1.RentalRate > table2.AvgRentalRate;




-- ###########################################################################
-- 12.Which films have been rented the most by customers living in each city?.
-- ###########################################################################

SELECT
    film_id,film.title,customer.first_name AS CustomerName,city.city,COUNT(*) AS times_rented
  FROM film
  LEFT JOIN inventory USING(film_id)
  LEFT JOIN rental USING(inventory_id)
  LEFT JOIN customer USING(customer_id)
  LEFT JOIN address USING(address_id)
  LEFT JOIN city USING(city_id)
GROUP BY film_id
ORDER BY 5 DESC ;

-- ##################################################################################
-- 13.What is the total amount spent by customers whose rental payments exceed $200?.
-- ##################################################################################

SELECT SUM(amount) AS TotalAmount
FROM payment
JOIN customer USING(customer_id)
WHERE customer.first_name IN 
(SELECT customer.first_name
FROM payment
INNER JOIN customer ON customer.customer_id = payment.customer_id
GROUP BY customer.first_name
HAVING SUM(payment.amount) > 200);

-- #############################################################################################
-- 14.Display the fields which are having foreign key constraints related to the "rental" table. 
--    [Hint: using Information_schema] .
-- #############################################################################################

SELECT i.TABLE_NAME, i.CONSTRAINT_TYPE, i.CONSTRAINT_NAME, k.REFERENCED_TABLE_NAME, k.REFERENCED_COLUMN_NAME 
FROM information_schema.TABLE_CONSTRAINTS i 
LEFT JOIN information_schema.KEY_COLUMN_USAGE k ON i.CONSTRAINT_NAME = k.CONSTRAINT_NAME 
WHERE i.CONSTRAINT_TYPE = 'FOREIGN KEY' 
AND i.TABLE_SCHEMA = 'film_rental'
AND i.TABLE_NAME = 'rental';

-- ######################################################################
-- 15.Create a View for the total revenue generated by each staff member, 
--    broken down by store city with the country name. 
-- ######################################################################

CREATE VIEW  RevenuebyStaff AS
SELECT s.first_name AS Staff, c.city AS City, ct.country AS Country,sum(p.amount) AS TotalRevenue
FROM payment p
JOIN staff s
ON p.staff_id = s.staff_id
JOIN address a 
ON s.address_id = a.address_id
JOIN city c
ON a.city_id = c.city_id
JOIN country ct
ON c.country_id = ct.country_id
GROUP BY c.city, s.first_name, ct.country
ORDER BY c.city;

SELECT * FROM RevenuebyStaff;

-- ##############################################################################################################
-- 16.Create a view based on rental information consisting of visiting_day, customer_name, the title of the film,  
--    no_of_rental_days, the amount paid by the customer along with the percentage of customer spending. 
-- ##############################################################################################################

CREATE VIEW RentalInformation AS
SELECT 
       DATE(r.rental_date) AS VisitingDay,
       c.first_name AS CustomerName,
       f.title AS FilmTitle,
       f.rental_duration AS NoRentalDays,
       SUM(p.amount) AS AmountPaid,
	   ROUND(SUM(p.amount) / SUM(SUM(p.amount)) OVER(), 4) * 100 AS TotalAmountPercentage
FROM film f 
JOIN inventory i  
ON f.film_id = i.film_id
JOIN rental r
ON i.inventory_id = r.inventory_id
JOIN customer c
ON r.customer_id =  c.customer_id
JOIN payment p 
ON c.customer_id = p.customer_id 
GROUP BY c.first_name
ORDER BY SUM(p.amount) DESC;

SELECT * FROM RentalInformation;

-- #################################################################################
-- 17.Display the customers who paid 50% of their total rental costs within one day. 
-- #################################################################################


