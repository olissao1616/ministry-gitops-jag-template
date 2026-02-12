"use client";

import Box from '@mui/material/Box';
import Grid from '@mui/material/Grid';
import { Button, Stack } from '@mui/material';
import { useRouter } from 'next/navigation';
import { containerMenu } from '@/app/_nonRoutingAssets/types/const';

export default function MainMenu() {
  const router = useRouter();
  return (
    <Box sx={{ "{{" }} flexGrow: 1 {{ "}}" }} key="a">
      <Grid container spacing={3}>
        <Grid item xs={1.5} />
        {containerMenu.map((topOption, index) => (
          <Grid key={index} item xs={4}>
            <Box sx={{ "{{" }} m: 8, p: 2, py: 1, border: '1px solid #CCCCCC',
              {{ "}}" }} width='340px' height='250px'>
              <div className='menuTopTitle'>{topOption.topTitle}</div>
              <Box sx={{ "{{" }} m: 6, border: '0px solid', {{ "}}" }}
                display="flex"
                flexDirection="column"
                alignItems="center"
                justifyContent='center'>
                 <Stack align-items="stretch" width="fit-content" spacing={2} >
                  {topOption.pages.map((page, index) => (
                    <Button sx={{ "{{" }}width: 240{{ "}}" }} key={index} color="primary" size='small' variant="contained" onClick={() => { router.push(page.route); }}>
                      {page.title}
                    </Button>
                  ))}
                </Stack>
              </Box>
            </Box>
          </Grid>
        ))}
      </Grid>
    </Box>
  );
}