# Full-Stack Tutorial: IMDb Web App

A step-by-step tutorial for creating a React web app that uses a variety of different technologies and AWS services to surface movie data in a useful way.

## Table of Contents

<ol style="list-style-type: upper-roman">
  <li>
    <a href="#rds">RDS</a>
  </li>
  <li>
    <a href="#ec2">EC2</a>
  </li>
  <li>
    <a href="#postgresql">PostgreSQL</a>
  </li>
  <li>
    <a href="#postgrest">PostgREST API</a>
  </li>
  <li>
    <a href="#react">React Web App</a>
  </li>
</ol>

---

<span id="#rds"></span>
## RDS


#### 1. Launch an Instance

The first step is to create an RDS database instance running PostgreSQL.  PostgreSQL is fast, powerful, and free, and has been [recently](https://thenewstack.io/6-things-for-developers-to-know-about-postgres) gaining in popularity.  Best of all, it has a very strong open-source community attached to it.

First, generate a secure password for to use with the RDS and store it as a string in the AWS Systems Manager [Parameter Store](https://console.aws.amazon.com/systems-manager/parameters).  As a parameter, it can be used in other places Cloudformation templates.

Afterwards, create a new free-tier eligible RDS instance. Use the RDS Console to create a new PostgreSQL database using the **Standard create** method.  It should have the following settings, along with the generated password stored in SSM:

Attribute | Value
--------- | -----
Engine | PostgreSQL
Templates | Free tier
DB instance identifier | imdb
Master password | *Generated Password*
Virtual private cloud (VPC) | Create new VPC
VPC Security Group | Create new
New VPC security group name | imdb-rds
Initial database name | postgres

#### 2. Networking

After launching the new RDS instance, view it in the Databases list and select it.

Copy down the endpoint in the **Connectivity & security** section.  This is the endpoint used in the DB section later on to remotely connect to the instance.

Still in **Connectivity & security**, find the link to the VPC under *Networking* and the link to the VPC security groups under *Security*, and open them into new browser tabs

In the **Security Groups** browser tab, select the security group from the list and add two tags: a **Name** tag with the value `IMDB RDS SG` and a **Project** tag with the value `IMDB`.  Keep this browser tab open

In the **VPC** browser tab, select the VPC from the list and add two tags: a **Name** tag with the value `IMDB VPC` and a **Project** tag with the value `IMDB`.  You can close this browser tab afterwards.

Switch views to the the **Tags** section and add two tags: a **Name** tag with the value `IMDB RDS` and a **Project** tag with the value `IMDB`.

---

<span id="#ec2"></span>
## EC2

#### 1. Launch an Instance

The next step is to create a free-tier EC2.  From your browser tab at the RDS section, switch over to the EC2 Console and launch a new Amazon Linux AMI-based instance with the following settings:

Attribute | Value
--------- | -----
Amazon Machine Image (AMI) | Amazon Linux 64bit x86
Instance Type | t2.micro
Network | IMDB VPC

Click through **Add Storage** and then add two tags: a **Name** tag with the value `IMDB API` and a **Project** tag with the value `IMDB`.

In the **Configure Security Group** section, create a new security group.  Give it the **Name** `imdb-ec2` and for **Description** put `Security group for the IMDB EC2`.

After **Review & Launch**, you'll be prompted about key pairs.  Select **Create a new key pair** and name it `imdb`.  Download it and use the command line to move it into your `.ssh` folder:

```
mv /path/to/imdb.pem ~/.ssh/imdb.pem
```

#### 2. Networking

After launching the new instance, view it in the Instances list and select it.  Copy down the **Public IPv4 DNS** endpoint in the **Details** tab.

Ths security group should have a single `SSH` rule (port 22) with the **Source** set to `My IP`.  This will detect your IP address automatically and open the SSH port only to your machine.  For the **Description** put `Private Access to SSH`.

Create a second `Custom TCP` rule with **Port range** set to `3000`.  Set the **Source** as `Anywhere` and for **Description** put `Public Access to API`.

Switch to the browser tab that has the RDS security group selected.  Create a single inbound rule of Type `PostgreSQL` – this will prefill the Protocol as `TCP` and the Port range as `5432`.

Under **Source** select the `Custom` option, and click in the field to select the EC2's security group (`imdb-ec2`) from the list.  For the optional **Description** field, put `Private Access to PSQL for IMDB EC2`.  Make sure to save the rule.

---

<span id="#postgresql"></span>
## PostgreSQL


#### 1. SSH into the EC2

Open up your local terminal.  In the command line, connect to your EC2 via `ssh` using your new key pair and the DNS endpoint:
```
chmod 600 ~/.ssh/imdb.pem 
ssh -i ~/.ssh/imdb.pem ec2-user@X-XXX-XXX-XX.compute-1.amazonaws.com
```

Agree to the prompt to add the EC2 to your known hosts (located at `~/.ssh/known_hosts`).  Look for the Amazon EC2 ASCII art to know that you've successfully connected.

```
The authenticity of host 'ec2-XX-XXX-XX-XXX.compute-1.amazonaws.com (XX.XXX.XX.XXX)' can't be established.
ECDSA key fingerprint is SHA256:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added 'ec2-XX-XXX-XX-XXX.compute-1.amazonaws.com,XX.XXX.XX.XXX' (ECDSA) to the list of known hosts.

       __|  __|_  )
       _|  (     /   Amazon Linux 2 AMI
      ___|\___|___|
```

#### 2. Download the IMDb data

Once you're inside, keep things organized.  Create a couple of directories for the IMDb project and its data:
```
mkdir imdb
cd imdb
mkdir data
cd data
```

Use `wget` to download and unzip the free IMDb datasets at the links provided in the [IMDb Datasets repo](https://datasets.imdbws.com/):
```
wget https://datasets.imdbws.com/title.basics.tsv.gz
gunzip title.basics.tsv.gz
```

For each dataset, output into a file starting at the 2nd line to create a copy without a header.  Limit your footprint by removing the original file TSV afterwards.
```
tail -n +2 title.basics.tsv > title.basics.noheader.tsv
rm title.basics.tsv
```


#### 3. Connect to the database

Download PostgreSQL 12.X into the EC2's Amazon Linux environment.  First update all your packages:
```
sudo yum -y update
```

Then add the package information for the official PostreSQL 12 repo on the server.  You can create a file on-the-fly as a [heredoc](https://tldp.org/LDP/abs/html/here-docs.html) by using the `tee` command with the redirection operator:
```
sudo tee /etc/yum.repos.d/pgdg.repo << EOF
[pgdg12]
name=PostgreSQL 12 for RHEL/CentOS 7 - x86_64
baseurl=https://download.postgresql.org/pub/repos/yum/12/redhat/rhel-7-x86_64
enabled=1
gpgcheck=0
EOF
```


Once the repo information is created, download and install PostgreSQL 12:
```
sudo yum makecache
sudo yum install postgresql12 postgresql12-server
```

If everything went successfully, you should now have a `psql` client that you can use to connect to your RDS instance remotely.  Check to make sure it's installed before moving on:
```
psql --version
>  psql (PostgreSQL) 12.6
```

Connect to the RDS instance using `psql` and the endpoint you copied down in the RDS section.  You'll be prompted for the RDS master password you generated and placed in Parameter Store.
```
psql -U postgres -h imdb-db.XXXXXXXXXXXX.us-east-1.rds.amazonaws.com -p 5432

>  Password for user postgres: 
>  psql (12.6, server 12.5)
>  SSL connection (protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384, bits: 256, compression: off)
>  Type "help" for help.

>  postgres=>
```

#### 4. Set up the database

The `psql`  prompt is now connected to the default database of your RDS instance as the `postgres` user.  You can now make changes to the database using SQL commands.  Start by creating a new schema dedicated to the API:
```
CREATE SCHEMA api;
```


Make sure you include semi-colons in order to execute each command.  The prompt will output the result of each command to let you know that execution was successful.

Create a role for the API and grant it privileges to the new schema.  By altering the default privileges of the `api` schema, you can give the role access to tables created in the future:
```
CREATE ROLE web_api NOLOGIN;
GRANT USAGE ON SCHEMA api TO web_api;
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT SELECT ON SEQUENCES TO web_api;
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT SELECT ON TABLES TO web_api;
```

##### 5. Import the IMDb data

In the `api` schema, create tables for the IMDb datasets.  As always, naming is important and the same rule applies as before:  stay consistent; which convention you choose is not so important.

For this tutorial, we'll follow [this excellent SQL style guide](https://www.sqlstyle.guide/) and keep our table names lowercased and [snake-cased](https://en.wikipedia.org/wiki/Snake_case) – e.g., we'll name the Title Basics table `title_basics` :
```
CREATE TABLE api.title_basics(
  tconst varchar(12),
  title_type varchar(80),
  primary_title varchar(512),
  original_title varchar(512),
  is_adult boolean,
  start_year smallint,
  end_year smallint,
  runtime_minutes int,
  genres varchar(80)
);
```

Use the `\copy` command to import the IMDb data from the unzipped TSV files.  A response with the number of entries imported will inform you that the copy was successful:
```
\copy api.title_basics FROM '/home/ec2-user/imdb/data/title.basics.noheader.tsv';
>  COPY 7681048
```

Take a look at the first five rows of the table to sanity check the copy, and get a quick look at the data and its structure:
```
SELECT * FROM api.title_basics LIMIT 5;

>    tconst   | title_type |     primary_title      |     original_title     | is_adult | start_year | end_year | runtime_minutes |          genres          
>  -----------+------------+------------------------+------------------------+----------+------------+----------+-----------------+--------------------------
>   tt0000001 | short      | Carmencita             | Carmencita             | f        |       1894 |          |               1 | Documentary,Short
>   tt0000002 | short      | Le clown et ses chiens | Le clown et ses chiens | f        |       1892 |          |               5 | Animation,Short
>   tt0000003 | short      | Pauvre Pierrot         | Pauvre Pierrot         | f        |       1892 |          |               4 | Animation,Comedy,Romance
>   tt0000004 | short      | Un bon bock            | Un bon bock            | f        |       1892 |          |              12 | Animation,Short
>   tt0000005 | short      | Blacksmith Scene       | Blacksmith Scene       | f        |       1893 |          |               1 | Comedy,Short
>  (5 rows)

```

---

<span id="#postgrest"></span>
## PostgREST API

#### 1. Install API and connect to RDS

Exit out of the `psql` prompt with **Ctrl-D** to return to the EC2 command prompt.  Move up a directory to ensure that you are in the `imdb` directory:

```
cd ..
pwd
> /home/ec2-user/imdb
```

This tutorial uses a pre-built API called **PostgREST** to serve the data from the PostgreSQL database.  Get the link to the the latest Linux x64 release [here](https://github.com/PostgREST/postgrest/releases/latest) and install it on the EC2 so that it can be executed globally:
```
wget https://github.com/PostgREST/postgrest/releases/download/v7.0.1/postgrest-v7.0.1-linux-x64-static.tar.xz
tar xJf postgrest-v7.0.1-linux-x64-static.tar.xz
sudo mv postgrest /usr/bin/postgrest
```

Use your RDS endpoint and the master password saved in Parameter Store to create a configuration file for PostgREST:
```
tee imdb.conf << EOF
db-uri = "postgres://postgres:MASTER_PASSWORD@imdb-db.XXXXXXXXXXXX.us-east-1.rds.amazonaws.com:5432/postgres"
db-schema = "api"
db-anon-role = "web_api"
db-pool = 10
EOF
```

You should now be able to run the API using the configuration file to serve database content from the RDS instance.  Start the API:
```
postgrest imdb.conf
>  Attempting to connect to the database...
>  Listening on port 3000
>  Connection successful
```

If everything is working, you should now be able to connect to your API to surface the IMDb data.  In your browser, paste a URL containing the EC2's **Public IPv4 DNS** and the API's open port (`3000`) with the following **PostgREST** query parameters:

```
http://ec2-XX-XXX-XX-XXX.compute-1.amazonaws.com:3000/title_basics?limit=5
```

In your browser, you should get a JSON-formatted response containing the first five rows of the `title_basics` table.  In your terminal, you should see a log of your IP Address hitting the API route:

```
XXX.XX.XXX.X - "GET /title_basics?limit=5 HTTP/1.1" 200 - "" "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_2_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.72 Safari/537.36"

```

#### 2. Daemonize the API

Exit out of PostgREST with **Ctrl-C** to return to your `imdb` directory.  Create a systemd file to register a service that runs PostgREST on startup. passing it the path to the `imdb.conf` configuration file:
```
sudo tee /etc/systemd/system/postgrest.service << EOF
[Unit]
Description=REST API for the IMDb database

[Service]
User=ec2-user

WorkingDirectory=/home/ec2-user/imdb

ExecStart=/usr/bin/postgrest /home/ec2-user/imdb/imdb.conf
SuccessExitStatus=143
TimeoutStopSec=10
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

Enable and start the service using `systemctl`, then check the status to make sure it's active and running:
```
sudo systemctl enable postgrest
sudo systemctl start postgrest
sudo systemctl status postgrest
>  ● postgrest.service - REST API for the IMDb database
>     Loaded: loaded (/etc/systemd/system/postgrest.service; enabled; vendor preset: disabled)
>     Active: active (running) since Sun 2021-03-07 17:25:05 UTC; 560ms ago
```

You should now be able to quit the SSH process using **Ctrl-D** and re-run the API call in your browser.  If the PostgREST API is successfully running as a service, you should still be able to get a response.

---

## External Links

- [Install PostgreSQL 12 on Amazon Linux](https://techviewleo.com/install-postgresql-12-on-amazon-linux/)
- [PostgREST Installation Guide](https://postgrest.org/en/stable/tutorials/tut0.html#step-3-install-postgrest)