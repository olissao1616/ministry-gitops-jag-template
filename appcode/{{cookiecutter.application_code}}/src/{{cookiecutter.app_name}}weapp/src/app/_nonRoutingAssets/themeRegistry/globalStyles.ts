import { css } from '@emotion/react'

export const globalStyles = (theme: any) => css`
  html {
    margin: 0;
    padding: 0;
    font-size: 16px;
    color: ${theme.palette.secondary.contrastText};
  }

  /*******
   * layout.css
   *******/
  body {
    margin: 0;
    padding: 0;
    background-color: ${theme.palette.background.paper};
  }

  /*******
   * headers
   *******/
  h1 {
    font-size: 2.125rem; // 34px for large headers
  }
  h2 {
      font-size: 1.5rem; // 24px for secondary headers
  }
  h3 {
      font-size: 1.25rem; // 20px for tertiary headers
      // color: 'red!important';
  }
  h4 {
      font-size: 1.125rem; // 18px for quaternary headers
  }
  h5 {
      font-size: 1rem; // 16px, the base font size for smaller headers
      // color: red !important;
  }
  h6 {
      font-size: 0.875rem; // 14px for the smallest headers
  }

  h1, h2, h3, h4, h5, h6 {
    margin: ${theme.spacing(4)} 0 ${theme.spacing(5)};
  }

  .layout {
    width: 100%;
    display: grid;
    grid:
      "header" auto
      "main" 1fr
      "footer" auto
      / auto;
    gap: 0 8px;
  }

  .flex-item {
    display: flex;
    align-items: center;
  }

  .main {
    grid-area: main;
  }

  @media only screen and (max-width: 500px){
    .L {
        width: auto;
        float: none;
    }

    .R {
        float: none;
        width: auto;
        position: static;
    }
  }

  .mask {
    position: fixed;
    left: 0;
    top: 0;
    z-index: 10; /* some high z-index */
    width: 100vw;
    height: 100vh;
    opacity: 0;
    user-select: none; /* prevents double clicking from highlighting entire page */
  }

  * {
    box-sizing: border-box;
  }

  /*******
   * styles.css
   *******/
  .header {
    background-color: ${theme.palette.primary.dark};
    grid-area: header;
    position: sticky;
  }

  .header-top {
    color: ${theme.palette.primary.contrastText};
    display: flex;
    flex-wrap: nowrap;
    height: 80px;
  }

  .header-section {
    padding: 10px 0;
    margin: 0 10px 0 0;
    height: 80px;
    max-width: 520px;
    flex-grow: 1;
    flex-shrink: 0;
    color: ${theme.palette.primary.contrastText};
  }

  .header-info {
    display: flex;
    justify-content: flex-end;
    align-items: flex-start;
    padding-top: 12px;
    padding-right: 10px;
    flex-grow: 1;
    flex-basis: 1;
    flex-shrink: 1;
    height: 70px;
  }

  .header-info img{
    border-radius: 50%;
  }
  .header-profile-button {
    border-radius: ${theme.spacing(11)};
    display: flex;
    align-items: center;
    height: 100%;
  }
  .header-text-container {
    font-weight: 700;
    margin-right: ${theme.spacing(1)};
    color: ${theme.palette.primary.contrastText};
    font-size: 1rem;
    white-space: wrap;
    overflow: hidden;
    text-align: right;
  }
  .header-img-container {
    margin-left: 60px;
  }
  // .header-text-agency {
  //   font-size: 12px;
  //   font-weight: 700;
  //   text-align: right;
  //   vertical-align: text-top;
  //   padding-left: 15px;
  //   padding-right: 0px;
  // }
  .text-sign-out {
    color: red
  }
  .header-img {
    display: inline-block;
    padding: 2px 14px 2px 20px;
    border-right: 1px solid ${theme.palette.secondary.main}
  }

  .headerText {
    font-weight: 700;
    color: ${theme.palette.primary.contrastText};
    position:relative;
    left: 15px;
    top: 0;
    font-size: 1.375rem;
  }

  .bcrumbs-bar-wrapper {
    padding: 0;
    margin-top: ${theme.spacing(2)};
    margin-bottom: ${theme.spacing(2)};
    margin-left: -${theme.spacing(6)};
  }

  .bcrumbs-bar {
    width: fit-content;
    padding: ${theme.spacing(1)} ${theme.spacing(2)};
    font-size: '0.875rem!important';
    background: ${theme.palette.grey[300]};
    border-radius: 5px;
    display: flex;
    cursor: default;
  }

  main {
    /* little formatting should be needed here */
    padding: 10px;
  }

  /******
   * style_header.css
   * ****/
  .headerNavContainer {
    width:100%;
    background-color: ${theme.palette.primary.dark};
    border-top: 2px solid ${theme.palette.secondary.main};
  }

  .navigation-text {
    font: normal normal bold 16px/28px BC Sans;
    text-align: left;
    color: ${theme.palette.primary.contrastText};
    padding: ${theme.spacing(1)} ${theme.spacing(4)} ${theme.spacing(2)};
  }
  .navigation-menu {
    background-color: ${theme.palette.primary.main};
    padding: 0 ${theme.spacing(4)} 0;
  }

  :focus {
    outline: 4px solid #3B99FC;
    outline-offset: 1px;
  }

  .page {
    margin-left: ${theme.spacing(10)};
    margin-right: ${theme.spacing(10)};
    margin-bottom: ${theme.spacing(5)};
    // margin-top: ${theme.spacing(2)};
  }

  .cross-section {
    font-weight: bold;
    letter-spacing: 0px;
    color: ${theme.palette.primary.contrastText};
  }

  .search-options {
    width: 75%;
    display: grid;
  }

  .search-options-fields {
      width: 100%;
      border-bottom: 1px solid ${theme.palette.primary.light};
  }
  /*
    These are sample media queries only. Media queries are quite subjective
    but, in general, should be made for the three different classes of screen
    size: phone, tablet, full.
  */

  @media screen and (min-width: 768px) {
    .navigation-menu {
      display: block;
    }
  }
`;

