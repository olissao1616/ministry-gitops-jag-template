"use client"
import React, { useEffect, useState } from 'react';
import { makeStyles, createStyles } from '@mui/styles'; // Import createStyles
import { Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Paper } from '@mui/material';
import { fetchUserData } from './action';

const useStyles = makeStyles(() =>
  createStyles({
    tableContainer: {
      maxWidth: 600,
      margin: 'left',
      marginTop: 20,
    },
    table: {
      minWidth: 300,
    },
    tableHeadCell: {
      fontWeight: 'bold',
    },
  })
);

const Page: React.FC = () => {
  const classes = useStyles(); // Call useStyles without arguments
  const [userData, setUserData] = useState<any>(null);
  const [loading, setLoading] = useState<boolean>(true);

  useEffect(() => {
    const fetchData = async () => {
      const data = await fetchUserData();
      if (data) {
        setUserData(data);
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  return (
    <div>
      {loading ? (
        <p>Loading...</p>
      ) : (
        <TableContainer component={Paper} className={classes.tableContainer}>
          <Table className={classes.table}>
            <TableHead>
              <TableRow>
                <TableCell className={classes.tableHeadCell}>Field</TableCell>
                <TableCell className={classes.tableHeadCell}>Value</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              <TableRow>
                <TableCell>ID</TableCell>
                <TableCell>{userData.id}</TableCell>
              </TableRow>
              <TableRow>
                <TableCell>First Name</TableCell>
                <TableCell>{userData.firstName}</TableCell>
              </TableRow>
              <TableRow>
                <TableCell>Last Name</TableCell>
                <TableCell>{userData.lastName}</TableCell>
              </TableRow>
              <TableRow>
                <TableCell>Email</TableCell>
                <TableCell>{userData.email}</TableCell>
              </TableRow>
              <TableRow>
                <TableCell>Roles</TableCell>
                <TableCell>{userData.role.join(', ')}</TableCell>
              </TableRow>
            </TableBody>
          </Table>
        </TableContainer>
      )}
    </div>
  );
};

export default Page;


